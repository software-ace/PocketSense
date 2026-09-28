# Pocket Sense

A personal finance tracker for Android and Linux. It works offline first: every screen reads a local database, and changes sync to Supabase whenever you're online.

## Features

**Home**
- Income, spending and net for this month, plus year-to-date spending.
- Daily spending chart for the last 30 days and a by-category breakdown.
- Recent activity with the time each entry was recorded.

**Activity**
- Add, edit and delete income and expense transactions, with a date, merchant, category and notes.
- **Add by voice:** tap 🎤 and say *"Spent 12.50 on lunch at Subway yesterday"*. The form opens filled in (amount, type, merchant, category, date) for you to check and save. On Android it uses the phone's speech recognizer. On Linux it runs an offline English model ([sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) streaming Zipformer, about 45 MB, downloaded once on first use to `~/.local/share/pocket_sense/speech/`). Either way, the sentence is interpreted on the device.
- Search by description or merchant, and filter by All, Expense or Income.
- On mobile: swipe to delete, long-press for more actions.

**Budgets**
- A weekly (Monday to Sunday) or monthly spending limit per expense category, with a progress bar, what's remaining, and an over-budget warning. Each card shows which week or month it covers.

**Recurring**
- Bills, subscriptions, salary and other recurring income or expenses, charged weekly, bi-weekly, monthly, quarterly or yearly from a first due date you choose.
- Shows "Due in N days" or "Overdue". **Post as transaction** records the item in one tap.
- Pause an item without deleting it.

**Accounts and sync**
- Email and password accounts, confirmed with an emailed code. Password reset also uses an emailed code, so there's no link to open.
- Each account's data is private: the database only returns a user's own rows (row-level security). Each account also has its own local database on the device.
- Offline first: changes save immediately on the device and upload about a second later, or as soon as you're back online. A cloud icon in the app bar shows the sync state (synced, waiting to upload, offline, or a problem). Tap it for details and **Sync now**.
- Pull to refresh on any tab.

**Settings**
- Manage income and expense categories, and see your account or log out. Open Settings from the gear icon.

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

It needs GTK 3 (installed on most desktops). Voice entry also needs `parecord`, which comes with PulseAudio or PipeWire's pulse tools (`pulseaudio-utils` on Debian/Ubuntu, `libpulse` on Arch). It's built on Ubuntu 22.04, so it runs on distros with glibc 2.35 or newer.

## Development

### Requirements
- Flutter (stable) with a Dart SDK that satisfies `^3.13.4`
- Android SDK for Android builds. Linux builds need the usual Flutter Linux desktop toolchain.

```sh
flutter pub get
flutter run            # pick an Android device or Linux
flutter analyze
flutter test
```

On Linux, the local database lives in `~/.local/share/pocket_sense/`.

### Supabase setup
The app talks to Supabase using the URL and **publishable** key in `lib/config.dart`. The publishable key is safe to ship inside the app because row-level security controls access. Never put the service-role key in the app.

To point it at a new project:
1. Create the four tables: `categories`, `transactions`, `budgets`, `recurring_expenses`. Their columns match the local schema in `lib/data/local_store.dart`.
2. Create your own account under **Authentication → Users**, then run the files in `supabase/migrations/` in order in the SQL editor. The per-user migration gives any existing rows to the one existing account, adds owner-only row-level security, blocks signed-out access, and gives each new account starter categories.
3. Under **Authentication → Emails → Templates**, add `{{ .Token }}` to the *Confirm signup* and *Reset Password* templates, because the app asks for the emailed code.
4. For anything beyond personal testing, configure custom SMTP. Supabase's built-in sender is limited to a few emails per hour.

### How sync works
Short version, in `lib/data/`:
- **Writes** go to the local SQLite database and to an outbox queue (`repo.dart`, `local_store.dart`).
- **Row IDs** are generated on the device and sent with each insert, so the local and server IDs always match.
- **`SyncController`** runs a sync about a second after any change, when the app is reopened, and when the network comes back. It runs one sync at a time and publishes the status shown by the cloud icon.
- **Each sync:**
  1. `SyncEngine` uploads the outbox in order.
  2. It compares every table's list of IDs and last-updated times with the server's.
  3. It downloads only rows that differ, and removes rows deleted elsewhere.
  4. When the same row changed on both sides, the newer `updated_at` wins.

### Releases
Pushing a tag like `v1.2.1` runs `.github/workflows/release.yml`, which:
1. runs `flutter analyze` and `flutter test`,
2. builds one APK per CPU type, with the version taken from the tag and the build number from the CI run number,
3. signs the APKs with the release key and checks each signature against the key's fingerprint,
4. publishes a GitHub Release using the notes in `.github/release-notes/<tag>.md`, or generated notes if that file is missing,
5. then builds the Linux bundle on Ubuntu 22.04 and attaches it to that release as `PocketSense-<tag>-linux-x64.tar.gz`.

A manual run (Actions → Release → Run workflow) builds everything and uploads the files as workflow artifacts instead of publishing a release.

**Signing:** every release must use the same key, or Android won't install an update over the existing app.
- Local builds read `android/key.properties`. It's gitignored and points to the keystore.
- CI reads the repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
- Without a key, local release builds fall back to debug signing. CI refuses to publish them.
- Keep a backup of the keystore and its password.

### Project layout
```
lib/
  data/        repo, local store, outbox, sync engine & controller, session
  voice/       speech engines: Android recognizer, Linux offline model (sherpa-onnx)
  models/      Category, Transaction, Budget, RecurringExpense
  screens/     Home, Activity, Budgets, Recurring, Categories, Settings, sign-in
  utils/       money/date formatting, recurring date math, layout helpers
  widgets/     sync indicator, empty/error/loading states
supabase/migrations/   SQL to run in the Supabase SQL editor
test/                  unit and widget tests (sync, outbox, local store, repo, auth, settings, voice)
                       desktop_speech_test.dart runs the real speech model; opt in with SPEECH_MODEL_DIR=<dir>
```

## Known limitations
- One currency (US dollars). Amounts are stored as integer cents.
- Android and Linux only.
