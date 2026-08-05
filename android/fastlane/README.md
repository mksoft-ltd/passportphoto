fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android internal

```sh
[bundle exec] fastlane android internal
```

Build and upload to the internal track

### android release

```sh
[bundle exec] fastlane android release
```

Build and upload to production (draft on a new app — roll out in console after the declarations)

### android upload_only

```sh
[bundle exec] fastlane android upload_only
```

Upload an already-built AAB without rebuilding

### android metadata_only

```sh
[bundle exec] fastlane android metadata_only
```

Upload listing text and images only (no binary)

### android promote

```sh
[bundle exec] fastlane android promote
```

Promote the internal track build to production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
