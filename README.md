# Pocket Sense

A personal finance tracker for Android and Linux. It works offline first: every screen reads a local database, and changes sync to Supabase whenever you're online. It also has a private AI assistant that runs entirely on your phone.

## Features

**Home**
- Income, spending and net for this month, plus year-to-date spending.
- Daily spending chart for the last 30 days and a by-category breakdown.
- Recent activity with the time each entry was recorded.

**Activity**
- Add, edit and delete income and expense transactions, with a date, merchant, category and notes.
- Search by description or merchant, and filter by All, Expense or Income.
- On mobile: swipe to delete, long-press for more actions.

**Budgets**
- A weekly (Monday to Sunday) or monthly spending limit per expense category, with a progress bar, what's remaining, and an over-budget warning. Each card shows which week or month it covers.

**Recurring**
- Bills, subscriptions, salary and other recurring income or expenses, charged weekly, bi-weekly, monthly, quarterly or yearly from a first due date you choose.
- Shows "Due in N days" or "Overdue". **Post as transaction** records the item in one tap.
- Pause an item without deleting it.

**Ask (on-device assistant)**
- Ask things like *"How much did I spend on dining this month?"* or *"Log $8.50 coffee at Blue Bottle"*.
- Runs [Qwen2.5-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF) (Q4_K_M, about 0.9 GB) through llama.cpp. The model downloads once, on your first question. After that the assistant works fully offline, and your data never leaves the device.
- It answers from your real data using read-only tools: summaries, search, budgets and recurring items. It can **add** transactions but never edit or delete them.

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

Download the APK for your phone from the [latest release](../../releases/latest):

| File | For |
|---|---|
| `PocketSense-<version>-arm64-v8a.apk` | Almost all modern Android phones |
| `PocketSense-<version>-armeabi-v7a.apk` | Older 32-bit phones |
| `PocketSense-<version>-x86_64.apk` | Emulators and Chromebooks |

Requires Android 7.0 (API 24) or later. The assistant needs about 3 GB of free RAM.

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
4. publishes a GitHub Release using the notes in `.github/release-notes/<tag>.md`, or generated notes if that file is missing.

**Signing:** every release must use the same key, or Android won't install an update over the existing app.
- Local builds read `android/key.properties`. It's gitignored and points to the keystore.
- CI reads the repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
- Without a key, local release builds fall back to debug signing. CI refuses to publish them.
- Keep a backup of the keystore and its password.

### Project layout
```
lib/
  ai/          on-device LLM (llamadart / llama.cpp)
  data/        repo, local store, outbox, sync engine & controller, session, assistant tools
  models/      Category, Transaction, Budget, RecurringExpense
  screens/     Home, Activity, Budgets, Recurring, Ask, Categories, Settings, sign-in
  utils/       money/date formatting, recurring date math, layout helpers
  widgets/     sync indicator, empty/error/loading states
supabase/migrations/   SQL to run in the Supabase SQL editor
test/                  unit and widget tests (sync, outbox, local store, repo, auth, settings)
```

## Known limitations
- One currency (US dollars). Amounts are stored as integer cents.
- The assistant adds transactions without asking you to confirm first.
- The assistant's chat history isn't saved.
- Android and Linux only.
