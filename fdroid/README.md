# F-Droid

`metadata/ace.software.pocketsense.yml` is the build recipe for [fdroiddata](https://gitlab.com/fdroid/fdroiddata). The store listing (descriptions, changelogs, icon) lives in `fastlane/metadata/android/`, where F-Droid reads it straight from this repo.

## How the recipe builds
- One build per CPU type, with versionCode `N × 10 + ABI`: armeabi-v7a `N1`, arm64-v8a `N2`, x86_64 `N3`, where `N` is the number after `+` in `pubspec.yaml`. `android/app/build.gradle.kts` sets this for the GitHub APKs too, replacing Flutter's `1000 × ABI + N`, as F-Droid asks, so a newer version always has the higher code whatever the ABI. The build number jumped to 500 at v2.2.4 so the new codes (5001+) stay above the old ones (up to 4019) and updates still install.
- **Reproducible builds:** F-Droid rebuilds each APK and publishes *ours*, the GitHub release APK named in `binary:`, only if its rebuild is identical apart from the signature. `AllowedAPKSigningKeys` is our release certificate. So F-Droid users get developer-signed APKs and can switch to or from the GitHub ones without reinstalling. For the two builds to match, the recipe copies `.github/workflows/release.yml` exactly:
  - It builds in CI's checkout path, `/home/runner/work/PocketSense/PocketSense`, with `HOME=/home/runner`: Dart's compiled code embeds the source path.
  - It uses the Flutter version pinned in `pubspec.yaml` (`environment: flutter:`); CI reads the same line.
  - It uses Java 21, the build server's default (Debian trixie); CI sets up Temurin 21.
  - The pub cache is inside the source tree, in both.
  - Both patch the `jni` package to link without a build ID, which otherwise hashes machine-specific paths.
  - Both use the same command, `flutter build apk --release --split-per-abi`, building all three ABIs; the native-assets manifest differs if only one is built.
- `UNSIGNED_RELEASE=1` makes Gradle leave the APK unsigned for F-Droid to compare. (Without it, a keyless build falls back to debug signing.)
- `PUB_CACHE` is inside the source tree so the scanner can see every dependency.
- `scandelete: .pub-cache` deletes the whole pub cache after `prebuild`, as the F-Droid reviewer asked, so the scanner skips third-party package files (prebuilt sherpa-onnx libraries, example apps and the like). `flutter build` then fetches the packages again; that still reproduces, because the build path is the same as CI's.
- The `hooks:` block in `pubspec.yaml` sets the sqlite3 package to `system` on Android, so the build downloads no native binaries. SQLCipher comes from Maven Central (`net.zetetic:sqlcipher-android`).

This was checked with fdroidserver 2.4.5: `fdroid lint` and `rewritemeta` are clean, and its source scanner reported 0 problems. Reproducibility was checked by running the recipe's commands in a `debian:trixie` container with F-Droid's paths and its default JDK: for all three ABIs, `apksigcopier compare` against the CI-built APKs passes. It was *not* run through a full `fdroid build` on F-Droid's build server.

**If a release stops matching**, F-Droid silently skips that version. Usually the cause is a change on one side only: a Flutter bump that doesn't go through `pubspec.yaml`, a CI step that changes the build, or a new native dependency that embeds paths.

## Submitting
1. Tag the release the recipe points at (`commit:` the full hash of `v2.2.1`, which fdroiddata requires instead of a tag), so the tag exists on GitHub.
2. Fork https://gitlab.com/fdroid/fdroiddata, copy `metadata/ace.software.pocketsense.yml` into its `metadata/`, and open a merge request using the "App inclusion" template.
3. F-Droid's CI runs `fdroid build` on the MR. If the Flutter version is no longer in their `srclibs`, bump `flutter@…` to one that is.

## Later releases
Nothing to do in fdroiddata: `UpdateCheckMode: Tags` finds new `v*` tags, reads the version from `pubspec.yaml`, and adds builds automatically. Just:
- bump `version:` in `pubspec.yaml` (always raise the `+N`),
- add `fastlane/metadata/android/<lang>/changelogs/<N>1.txt`, `<N>2.txt` and `<N>3.txt`,
- tag `v<version>`.

To upgrade Flutter, change `environment: flutter:` in `pubspec.yaml`. CI and F-Droid both read it, so there's nothing to change in the recipe.

