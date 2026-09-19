import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../specs/specs_repository.dart';
import 'face_overlay.dart';

/// What went wrong, and what the user can do about it.
///
/// A denied permission used to render as the bare string "Camera permission
/// denied." with no way forward — and because the OS stops showing its dialog
/// once a denial is permanent, every later visit to `/capture` landed on the
/// same dead screen. The recovery action is part of the error, not an
/// afterthought, so an error state without one cannot be constructed.
enum _Recovery {
  /// Retrying may work — the OS will ask again.
  retry,

  /// The OS will not ask again; only Settings can undo this.
  openSettings,
}

class _CaptureError {
  const _CaptureError(this.message, {this.recovery = _Recovery.retry});
  final String message;
  final _Recovery recovery;
}

/// The OS doing the refusing, for the permanently-denied copy.
///
/// The app is live on Google Play as well as the App Store, and this message
/// named iOS unconditionally until 2026-09-19, so every Android user who
/// tapped "Don't allow" twice was told about an operating system they were not
/// using. Same reasoning as `PurchaseService._storeName`, which already takes
/// this care over naming the right store.
String get _osName => !kIsWeb && Platform.isIOS ? 'iOS' : 'Android';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  _CaptureError? _error;
  bool _busy = false;
  bool _useFront = true;

  /// Guards [_initialise] against overlapping runs. Without it, two quick
  /// background/foreground cycles start two initialisations; whichever finishes
  /// second overwrites `_controller` and the first camera session is never
  /// closed — on iOS that holds the hardware and keeps the green privacy
  /// indicator lit for the rest of the session.
  bool _initialising = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initialise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = _controller;
      if (c == null) return;
      // Clear the field as well as disposing it. `CameraController.dispose()`
      // does not reset `value.isInitialized` — in camera 0.11.4 it only sets a
      // private `_isDisposed` — so a disposed controller left installed makes
      // build()'s `!c.value.isInitialized` guard read stale-true. The screen
      // then renders `CameraPreview` over a texture whose platform-side session
      // has been released, and the shutter stays live over it.
      _controller = null;
      if (mounted) setState(() {});
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Deliberately not gated on `_controller`: this is also the path back
      // from the Settings app, where the user may have just granted the
      // permission that failed the first attempt.
      _initFuture = _initialise();
      if (mounted) setState(() {});
    }
  }

  Future<void> _initialise() async {
    if (_initialising) return;
    _initialising = true;
    // Cleared on every attempt. Leaving it set is what made a single tap on
    // "Don't Allow" permanent: nothing else ever reset it, not even a
    // successful initialisation after the user fixed the permission.
    if (_error != null && mounted) setState(() => _error = null);

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _fail(
          status.isPermanentlyDenied || status.isRestricted
              ? _CaptureError(
                  'Passport Photo Studio does not have permission to use the '
                  'camera, and $_osName will not ask again from inside the '
                  'app. You can turn it on in Settings, or use a photo you '
                  'already have.',
                  recovery: _Recovery.openSettings,
                )
              : const _CaptureError(
                  'Camera access is needed to take a new photo. Allow it when '
                  'asked, or use a photo you already have instead.',
                ),
        );
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail(const _CaptureError(
          'No camera is available on this device. You can still pick a photo '
          'from your library.',
        ));
        return;
      }

      final wanted = _useFront
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == wanted,
        orElse: () => cameras.first,
      );

      // One owner for the session: whatever is installed is released here,
      // before a replacement is opened, whether it got there from a lifecycle
      // resume or from the camera-flip button.
      final previous = _controller;
      if (previous != null) {
        _controller = null;
        if (mounted) setState(() {});
        await previous.dispose();
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {});
    } on CameraException catch (e) {
      // `CameraAccessDenied` reaches here when the plugin's own authorization
      // check fails even though permission_handler reported granted — rare, but
      // it is a permission problem and deserves the permission recovery.
      _fail(
        e.code.startsWith('CameraAccessDenied')
            ? const _CaptureError(
                'The camera is not available to this app. Check its permission '
                'in Settings, or use a photo you already have.',
                recovery: _Recovery.openSettings,
              )
            : const _CaptureError(
                'The camera could not be started. Close any other app that '
                'might be using it and try again.',
              ),
      );
    } catch (_) {
      _fail(const _CaptureError(
        'The camera could not be started. Try again, or use a photo you '
        'already have.',
      ));
    } finally {
      _initialising = false;
    }
  }

  /// Every error path goes through here, so none of them can `setState` on an
  /// unmounted `State`. `Permission.camera.request()` routinely resolves after
  /// the user has backed out of the screen.
  void _fail(_CaptureError error) {
    if (!mounted) return;
    setState(() => _error = error);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final picture = await c.takePicture();
      if (!mounted) return;
      context.replace('/result', extra: picture.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That photo could not be taken. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flipCamera() {
    // `_initialise` refuses to start while another run is in flight, so
    // toggling first would leave `_useFront` describing a camera that was
    // never opened: the next tap would then "flip" back to the lens already on
    // screen and the button would look broken. Nothing to flip to yet is the
    // honest reading of a tap during start-up.
    if (_initialising) return;
    _useFront = !_useFront;
    // `_initialise` disposes the outgoing controller itself.
    _initFuture = _initialise();
    setState(() {});
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null || !mounted) return;
    context.replace('/result', extra: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(selectedSpecProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(spec?.displayLabel ?? 'Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Switch camera',
            onPressed: _error == null ? _flipCamera : null,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          final error = _error;
          if (error != null) return _buildError(error);

          final c = _controller;
          if (c == null || !c.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.previewSize?.height ?? 0,
                    height: c.value.previewSize?.width ?? 0,
                    child: CameraPreview(c),
                  ),
                ),
              ),
              if (spec != null) Positioned.fill(child: FaceOverlay(spec: spec)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Center(
                  child: GestureDetector(
                    onTap: _busy ? null : _capture,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white70, width: 4),
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.black54,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(_CaptureError error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (error.recovery == _Recovery.openSettings)
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open Settings'),
              )
            else
              FilledButton.icon(
                onPressed: () {
                  _initFuture = _initialise();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            const SizedBox(height: 12),
            // The gallery path is untouched by any camera permission, so this
            // is always a real way to finish the job rather than a consolation.
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.image_rounded, color: Colors.white70),
              label: const Text(
                'Pick from gallery instead',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
