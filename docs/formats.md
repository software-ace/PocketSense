# File formats

Pocket Sense reads and writes two kinds of file:

- **CSV files** (**Settings → Data**, and the ⋮ menu on Categories and Merchants). Importing one **adds** rows. It never changes or removes anything.
- **Backup files** (**Settings → Backup**). Importing one **replaces everything** in the app.

If you're converting transactions from another app or a bank statement, write a **transactions CSV**. It shows a preview before saving, skips rows you already have, and leaves your categories, budgets and accounts as they are.

## CSV

- UTF-8, comma-separated, with a header row. Quoting follows RFC 4180: a field may be wrapped in `"…"`, and a `"` inside it is written `""`.
- Columns are found by their header name, in any order and any letter case. Extra columns are ignored.
- Rows may end with CRLF or LF. A byte order mark at the start is allowed. Exports always write one so that Excel reads Arabic correctly.

### Transactions

| Column | Required | Value |
|---|---|---|
| `date` | yes | `yyyy-MM-dd`, a real day (`2026-02-30` is rejected) |
| `type` | yes | `income` or `expense` |
| `amount` | yes | Positive, with a `.` decimal point and up to 3 decimals. A `,` is allowed only as a thousands separator (`1,250.5`). `12,5` is rejected. |
| `description` | yes | Any text |
| `category` | no | Matched by name and type, in any letter case. An unknown or empty category leaves the entry uncategorized. |
| `merchant` | no | Added to your merchants if you don't have it yet |
| `account` | no | Matched by name. An unknown or empty account puts the entry in your default account. |

A row with the same `date`, `type`, `amount` and `description` as an entry you already have counts as a duplicate and is skipped. Two identical rows in a file both import if you have neither yet, so two coffees on one day both stay.

```csv
date,type,amount,description,category,merchant,account
2026-11-01,expense,2.75,Coffee,Coffee,Café Rumi,Cash
2026-11-01,income,1250,Monthly salary,Salary,,Bank
```

### Categories

| Column | Required | Value |
|---|---|---|
| `name` | yes | A name you already have, in any letter case, is a duplicate |
| `type` | yes | `income` or `expense` |
| `color` | no | `#rrggbb`. Defaults to grey. |

### Merchants

One column, `name`. A name you already have, in any letter case, is a duplicate.

## Backup (JSON)

A backup is one JSON object:

```json
{
  "format": "pocketsense-backup",
  "version": 4,
  "exported_at": "2026-11-08T18:00:00.000Z",
  "currency": "JOD",
  "tables": {
    "categories": [{ "id": 1, "name": "Groceries", "type": "expense", "color": "#22c55e" }],
    "accounts": [{ "id": 1, "name": "Cash", "kind": "cash", "opening_fils": 0, "closed": 0 }],
    "transactions": [
      { "id": 1, "amount_fils": 2750, "type": "expense", "date": "2026-11-01",
        "description": "Coffee", "category_id": 1, "account_id": 1 }
    ]
  }
}
```

[`demo-backup.json`](demo-backup.json) is a complete example with every table.

- `format` must be `pocketsense-backup`.
- `version` must be from 1 to 4. A file from a newer app is refused rather than partly read.
- `currency` is an ISO 4217 code that the app supports. Importing switches the app to it.
- **Money** (`*_fils`) is a whole number of thousandths of the currency's main unit, whatever the currency: `2750` is 2.750 JOD, or 2.75 USD.
- **Dates** are `yyyy-MM-dd`. `created_at` is an ISO 8601 timestamp; it orders entries made on the same day.
- **`id`** is a whole number, unique within its table. Other tables point to a row by its `id`.
- **`uid`** is optional. It's what keeps a row the same row on paired devices, and a row without one gets a new one.
- A table that's missing is read as empty. A column that's missing takes its default.
- If `accounts` is empty, the app makes a single Cash account and puts everything in it.
- Unknown columns are ignored. The whole file is checked before anything is replaced, so a file with a bad row changes nothing.

Tables and their columns. **Bold** columns are required.

| Table | Columns |
|---|---|
| `categories` | **`id`**, **`name`** (unique, in any letter case), **`type`** (`income`/`expense`), **`color`** (`#rrggbb`) |
| `merchants` | **`id`**, **`name`** (unique, in any letter case) |
| `accounts` | **`id`**, **`name`**, **`kind`** (`cash`/`bank`/`savings`/`card`/`ewallet`), `opening_fils`, `closed` (`0`/`1`) |
| `loans` | **`id`**, **`direction`** (`lent`/`borrowed`), **`person`**, `due_date`, `note`, `due_time`, `reminder_days` |
| `circles` | **`id`**, **`name`**, **`contribution_fils`**, **`rounds`**, **`frequency`** (`weekly`/`biweekly`/`monthly`), **`start_date`**, **`payout_round`**, `note`, `due_time`, `reminder_days` |
| `transactions` | **`id`**, **`amount_fils`** (positive), **`type`**, **`date`**, **`description`**, `merchant`, `category_id`, `account_id`, `loan_id`, `circle_id`, `created_at` |
| `budgets` | **`id`**, **`category_id`**, **`limit_fils`**, `period` (`weekly`/`monthly`) |
| `recurring_expenses` | **`id`**, **`description`**, **`amount_fils`**, **`frequency`** (`weekly`/`biweekly`/`monthly`/`quarterly`/`yearly`), **`anchor_date`**, `type`, `category_id`, `merchant`, `notes`, `active` (`0`/`1`), `account_id`, `due_time`, `reminder_days` |
| `transfers` | **`id`**, **`from_account_id`**, **`to_account_id`**, **`amount_fils`**, **`date`**, `note`, `created_at` |

`due_time` is the time of day in minutes after midnight (`1080` is 18:00). `reminder_days` is how many days before to remind (`0` means on the day). An empty value means no reminder.

A transaction's `merchant` is plain text. The `merchants` table is the list the merchant picker offers.

## Encrypted backup

Export asks whether to encrypt, and recommends it. Automatic backups are always encrypted. An encrypted file wraps the backup JSON above:

```json
{
  "format": "pocketsense-backup-encrypted",
  "version": 1,
  "kdf": "pbkdf2-sha256",
  "iterations": 200000,
  "salt": "<base64, 16 bytes>",
  "nonce": "<base64, 12 bytes>",
  "data": "<base64: ciphertext, then the 16-byte GCM tag>"
}
```

- **Key:** PBKDF2-HMAC-SHA256 of the UTF-8 password with `salt` and `iterations`, giving 32 bytes.
- **Cipher:** AES-256-GCM with `nonce` and no associated data. The plaintext is the UTF-8 backup JSON.

Any standard crypto library can read or write these files. A wrong password and a damaged file both fail the GCM tag check.
