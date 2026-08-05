import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  FaceDetectorService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableLandmarks: true,
            enableContours: false,
            enableClassification: true,
            enableTracking: false,
            performanceMode: FaceDetectorMode.accurate,
            minFaceSize: 0.15,
          ),
        );

  final FaceDetector _detector;

  Future<List<Face>> detectFromFile(String path) {
    return _detector.processImage(InputImage.fromFilePath(path));
  }

  void dispose() {
    _detector.close();
  }
}
