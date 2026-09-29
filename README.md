# Pocket Sense

A private, offline personal finance tracker for Android and Linux, in Jordanian dinars, in English and Arabic. There are no accounts and no servers: your data lives in an encrypted database on your device, and it only leaves when you export a backup.

## Features

**First run**
- A two-step welcome: **import a backup** (for example from your old phone) or **start fresh**, then **set a PIN**, and on Android turn on fingerprint or face unlock. Both steps can be changed later in Settings. Erasing all data brings the welcome back.

**Home**
- Income, spending and net for this month, plus spending so far this year.
- Daily spending chart for the last 30 days and a by-category breakdown.
- Recent activity with the time each entry was recorded.

**Activity**
- Add, edit and delete income and expense transactions, with a date, merchant, category and notes.
- **Add by voice:** tap 🎤 and say *"Spent 3.5 on lunch at Reem yesterday"* or *"12 dinars and 500 fils for groceries"*. The form opens filled in (amount, type, merchant, category, date) for you to check and save. Voice entry understands English only, whichever language the app is in. On Android it uses the phone's speech recognizer. On Linux it runs an offline English model ([sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) streaming Zipformer, about 45 MB, downloaded once on first use to `~/.local/share/pocket_sense/speech/`). Either way, the sentence is interpreted on the device.
- Search by description or merchant, and filter by All, Expense or Income.
- On mobile: swipe to delete, long-press for more actions.

**Budgets**
- A weekly (Monday to Sunday) or monthly spending limit per expense category, with a progress bar, what's remaining, and an over-budget warning. Each card shows which week or month it covers.

**Recurring**
- Bills, subscriptions, salary and other recurring income or expenses, charged weekly, bi-weekly, monthly, quarterly or yearly from a first due date you choose.
- Shows "Due in N days" or "Overdue". **Post as transaction** records the item in one tap.
- Pause an item without deleting it.

**Money**
- Amounts are in Jordanian dinars with three decimals: **JOD 12.500** in English, **12.500 د.أ** in Arabic. Digits are Latin (0–9) in both languages.
- Amount fields accept Arabic-Indic digits and `٫` too.

**Languages**
- English and Arabic, right-to-left in Arabic. **Settings → Language** picks one, or follows the system.
- Starter categories are created in the language you first open the app in.

**Privacy and security**
- **Offline:** no account, no sync, no analytics. The Android app doesn't even request the INTERNET permission. (On Linux, the only network use is the one-time voice model download.)
- **Encrypted database:** SQLCipher, with a random 256-bit key kept in the Android Keystore, or the Secret Service (GNOME Keyring, KWallet) on Linux.
- **App lock:** **Settings → Security** adds a 4–6 digit PIN, asked for at launch and after 30 seconds in the background. On Android you can also unlock with a fingerprint or face. After 5 wrong PINs the app makes you wait, 30 s and then longer each time.
- A forgotten PIN can't be recovered. The lock screen offers to erase everything and start over; you can then import a backup.
- Android system backup is turned off, because a restored database couldn't be opened without its Keystore key. Use export instead.

**Backup**
- **Settings → Backup → Export data** saves everything to a JSON file you choose. The file is **not encrypted**, so the app warns before writing it.
- **Import data** replaces everything with a backup file. The file is fully checked first, and if anything in it is invalid, nothing changes.

**Settings**
- Language, app lock, categories, and backup. Open Settings from the gear icon.

**Layout**
- Phone layout with a bottom tab bar. On windows 900 px or wider (desktop, tablets) it switches to a side navigation rail with wider layouts.

## Install

Download from the [latest release](../../releases/latest).

**Android:** pick the APK for your phone.

| File | For |
|---|---|
| `PocketSense-<version>-arm64-v8a.apk` | Almost all modern Android phones |
| `PocketSense-<version>-armeabi-v7a.apk` | Older 32-bit phones |
| `PocketSense-<version>-x86_64.apk` | Emulators and Chromebooks |

Requires Android 7.0 (API 24) or later.

**Linux (x86_64):** download `PocketSense-<version>-linux-x64.tar.gz`, then:

```sh
tar -xzf PocketSense-<version>-linux-x64.tar.gz
./PocketSense/pocket_sense
```

It needs:
- GTK 3 (installed on most desktops).
- A running Secret Service for the encryption key: GNOME Keyring or KWallet, which most desktops already run. Without one, the app explains the problem instead of starting.
- For voice entry, `parecord`, which comes with PulseAudio or PipeWire's pulse tools (`pulseaudio-utils` on Debian/Ubuntu, `libpulse` on Arch).

SQLCipher is bundled. It's built on Ubuntu 22.04, so it runs on distros with glibc 2.35 or newer.

## Development

### Requirements
- Flutter (stable) with a Dart SDK that satisfies `^3.13.4`.
- Android SDK for Android builds. Linux builds need the usual Flutter Linux desktop toolchain plus `libsecret-1-dev`.

```sh
flutter pub get
flutter run            # pick an Android device or Linux
flutter analyze
flutter test
```

On Linux, the database is `~/.local/share/pocket_sense/pocketsense.db` (encrypted).

### Storage and encryption
- `lib/data/local_store.dart` owns the one database. Its schema is versioned (`schemaVersion`); add an `onUpgrade` step when it changes. It also seeds the starter categories.
- `lib/data/db_key.dart` creates the key on first launch and reads it from the OS keystore afterwards.
- **Android** opens the database through `sqflite_sqlcipher`, which uses SQLCipher from Maven Central (`net.zetetic:sqlcipher-android`).
- **Linux** (and unit tests on a Linux host) use `sqflite_common_ffi` with the `sqlite3` package's own SQLCipher build. It's selected by the `hooks:` block in `pubspec.yaml`: `sqlcipher` on Linux, `system` elsewhere, so the Android build downloads no native binaries.
- The system `libsqlcipher` can't be used on Linux. GTK already loads the system `libsqlite3`, and SQLCipher's internal calls bind to that copy and crash. The bundled build is linked with `-Bsymbolic`, which avoids this.
- Opening fails loudly if `PRAGMA cipher_version` doesn't answer, so a misconfigured build can never write an unencrypted file.

### Localization
- Strings live in `lib/l10n/app_en.arb` (the template) and `app_ar.arb`. `flutter gen-l10n` (also run by `flutter pub get`/`run`) regenerates `app_localizations*.dart`, which are committed.
- In widgets, use `context.l10n.someKey`. Money and dates follow the UI language through `AppSettings.applyToIntl`.
- Money helpers are in `lib/utils/format.dart`: `formatMoney`, `parseAmount`, `amountToInput`. Amounts are integer fils everywhere; never use doubles for money.

### Releases
Pushing a tag like `v2.0.0` runs `.github/workflows/release.yml`, which:
1. runs `flutter analyze` and `flutter test`,
2. checks that the tag matches the version in `pubspec.yaml`, then builds one APK per CPU type. The version name and build number come from `pubspec.yaml`, the same place F-Droid reads them,
3. signs the APKs with the release key and checks each signature against the key's fingerprint,
4. publishes a GitHub Release using the notes in `.github/release-notes/<tag>.md`, or generated notes if that file is missing,
5. then builds the Linux bundle on Ubuntu 22.04 and attaches it to that release as `PocketSense-<tag>-linux-x64.tar.gz`.

**To cut a release:** bump `version:` in `pubspec.yaml`, always increasing the number after `+`, then commit and tag `v<version>`.

A manual run (Actions → Release → Run workflow) builds everything and uploads the files as workflow artifacts instead of publishing a release.

**Signing:** every release must use the same key, or Android won't install an update over the existing app.
- Local builds read `android/key.properties`. It's gitignored and points to the keystore.
- CI reads the repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
- Without a key, local release builds fall back to debug signing. CI refuses to publish them.
- Keep a backup of the keystore and its password.

### Project layout
```
lib/
  data/        local store (encrypted SQLite), DB key, repo, JSON backup
  security/    app lock: PIN hashing and throttling, lock screen, biometrics
  settings/    app preferences (language)
  l10n/        English and Arabic strings (ARB) and generated localizations
  voice/       speech engines: Android recognizer, Linux offline model (sherpa-onnx)
  models/      Category, Transaction, Budget, RecurringExpense, starter categories
  screens/     Home, Activity, Budgets, Recurring, Categories, Settings
  utils/       money/date formatting, recurring date math, voice parsing, layout helpers
  widgets/     amount field, empty/error/loading states, voice sheet
assets/fonts/  Noto Sans Arabic (SIL OFL 1.1)
test/          unit and widget tests
               desktop_speech_test.dart runs the real speech model; opt in with SPEECH_MODEL_DIR=<dir>
```

## Known limitations
- One currency: Jordanian dinars.
- Android and Linux only. Biometric unlock is Android-only.
- Voice entry understands English sentences only.
- Arabic month names follow the standard (سبتمبر) rather than the Levantine (أيلول) names.
