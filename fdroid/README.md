# F-Droid

`metadata/ace.software.pocketsense.yml` is the build recipe for [fdroiddata](https://gitlab.com/fdroid/fdroiddata). The store listing (descriptions, changelogs, icon) lives in `fastlane/metadata/android/`, where F-Droid reads it straight from this repo.

## How the recipe builds
- One build per CPU type, with versionCode `1000 × ABI + N`: armeabi-v7a `1000 + N`, arm64-v8a `2000 + N`, x86_64 `4000 + N`. `N` is the number after `+` in `pubspec.yaml`, and it's the same scheme Flutter's `--split-per-abi` uses for the GitHub APKs.
- **Reproducible builds:** F-Droid rebuilds each APK and publishes *ours*, the GitHub release APK named in `binary:`, only if its rebuild is identical apart from the signature. `AllowedAPKSigningKeys` is our release certificate. So F-Droid users get developer-signed APKs and can switch to or from the GitHub ones without reinstalling. For the two builds to match, the recipe copies `.github/workflows/release.yml` exactly:
  - It builds in CI's checkout path, `/home/runner/work/PocketSense/PocketSense`, with `HOME=/home/runner`: Dart's compiled code embeds the source path.
  - It uses the Flutter version pinned in `pubspec.yaml` (`environment: flutter:`); CI reads the same line.
  - It uses Java 21, the build server's default (Debian trixie); CI sets up Temurin 21.
  - The pub cache is inside the source tree, in both.
  - Both patch the `jni` package to link without a build ID, which otherwise hashes machine-specific paths.
  - Both use the same command, `flutter build apk --release --split-per-abi`, building all three ABIs; the native-assets manifest differs if only one is built.
- `UNSIGNED_RELEASE=1` makes Gradle leave the APK unsigned for F-Droid to compare. (Without it, a keyless build falls back to debug signing.)
- `PUB_CACHE` is inside the source tree so the scanner can see every dependency.
- `scandelete` removes things from the pub cache that never reach the APK but that the scanner rejects:
  - sherpa-onnx's prebuilt speech libraries (the Linux app's offline voice model; Android uses the phone's recognizer and never loads them). The Android package is `ffiPlugin`-only, so nothing loads them at startup either.
  - plugins' `example/` apps, a devtools web extension, and a package's shipped test build output.
  - a demo page with a `.zip` in `archive`, which Flutter's own command-line tool fetches into the same cache (it's not an app dependency).
- The `hooks:` block in `pubspec.yaml` sets the sqlite3 package to `system` on Android, so the build downloads no native binaries. SQLCipher comes from Maven Central (`net.zetetic:sqlcipher-android`).

This was checked with fdroidserver 2.4.5: `fdroid lint` and `rewritemeta` are clean, and its source scanner reports 0 problems on a fresh clone with these `scandelete` paths. Reproducibility was checked by running the recipe's commands in a `debian:trixie` container with F-Droid's paths and its default JDK: for all three ABIs, `apksigcopier compare` against the CI-built APKs passes. It was *not* run through a full `fdroid build` on F-Droid's build server.

**If a release stops matching**, F-Droid silently skips that version. Usually the cause is a change on one side only: a Flutter bump that doesn't go through `pubspec.yaml`, a CI step that changes the build, or a new native dependency that embeds paths.

## Submitting
1. Tag the release the recipe points at (`commit:` the full hash of `v2.2.1`, which fdroiddata requires instead of a tag), so the tag exists on GitHub.
2. Fork https://gitlab.com/fdroid/fdroiddata, copy `metadata/ace.software.pocketsense.yml` into its `metadata/`, and open a merge request using the "App inclusion" template.
3. F-Droid's CI runs `fdroid build` on the MR. If the Flutter version is no longer in their `srclibs`, bump `flutter@…` to one that is.

## Later releases
Nothing to do in fdroiddata: `UpdateCheckMode: Tags` finds new `v*` tags, reads the version from `pubspec.yaml`, and adds builds automatically. Just:
- bump `version:` in `pubspec.yaml` (always raise the `+N`),
- add `fastlane/metadata/android/<lang>/changelogs/<1000+N>.txt`, `<2000+N>.txt` and `<4000+N>.txt`,
- tag `v<version>`.

To upgrade Flutter, change `environment: flutter:` in `pubspec.yaml`. CI and F-Droid both read it, so there's nothing to change in the recipe.

If a dependency upgrade makes a `scandelete` path stop matching, F-Droid's build fails with "Some glob paths did not match". Remove that line from the recipe in fdroiddata.
