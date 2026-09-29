# F-Droid

`metadata/ace.software.pocketsense.yml` is the build recipe for [fdroiddata](https://gitlab.com/fdroid/fdroiddata). The store listing (descriptions, changelogs, icon) lives in `fastlane/metadata/android/`, where F-Droid reads it straight from this repo.

## How the recipe builds
- One build per CPU type, with versionCode `1000 × ABI + N`: armeabi-v7a `1000 + N`, arm64-v8a `2000 + N`, x86_64 `4000 + N`. `N` is the number after `+` in `pubspec.yaml`, and it's the same scheme Flutter's `--split-per-abi` uses for the GitHub APKs.
- `UNSIGNED_RELEASE=1` makes Gradle leave the APK unsigned, so F-Droid signs it with its own key. (Without it, a keyless build falls back to debug signing.)
- `PUB_CACHE` is inside the source tree so the scanner can see every dependency.
- `scandelete` removes things from the pub cache that never reach the APK but that the scanner rejects:
  - sherpa-onnx's prebuilt speech libraries (the Linux app's offline voice model; Android uses the phone's recognizer and never loads them). The Android package is `ffiPlugin`-only, so nothing loads them at startup either.
  - plugins' `example/` apps, a devtools web extension, and a package's shipped test build output.
- The `hooks:` block in `pubspec.yaml` sets the sqlite3 package to `system` on Android, so the build downloads no native binaries. SQLCipher comes from Maven Central (`net.zetetic:sqlcipher-android`).

This was checked with fdroidserver 2.4.5: `fdroid lint` and `rewritemeta` are clean, and its source scanner reports 0 problems on a fresh clone with these `scandelete` paths, after which the APK still builds. It was *not* run through a full `fdroid build` on F-Droid's build server.

## Submitting
1. Tag the release the recipe points at (`commit: v2.0.1`), so the tag exists on GitHub.
2. Fork https://gitlab.com/fdroid/fdroiddata, copy `metadata/ace.software.pocketsense.yml` into its `metadata/`, and open a merge request using the "App inclusion" template.
3. F-Droid's CI runs `fdroid build` on the MR. If the Flutter version is no longer in their `srclibs`, bump `flutter@…` to one that is.

## Later releases
Nothing to do in fdroiddata: `UpdateCheckMode: Tags` finds new `v*` tags, reads the version from `pubspec.yaml`, and adds builds automatically. Just:
- bump `version:` in `pubspec.yaml` (always raise the `+N`),
- add `fastlane/metadata/android/<lang>/changelogs/<1000+N>.txt`, `<2000+N>.txt` and `<4000+N>.txt`,
- tag `v<version>`.

If a dependency upgrade makes a `scandelete` path stop matching, F-Droid's build fails with "Some glob paths did not match". Remove that line from the recipe in fdroiddata.
