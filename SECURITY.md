# Security policy

Pocket Sense holds people's financial data, so security reports get priority.

## Supported versions

Only the latest release gets fixes. Check yours under **Settings → About** and update before reporting.

## Reporting a problem

**Please don't open a public issue.** [Report it privately](https://github.com/software-ace/PocketSense/security/advisories/new) instead. Only you and the maintainer can see the report.

Include:
- the Pocket Sense version, platform (Android or Linux) and where you installed it from
- what an attacker can do, and what they need first (on the same Wi-Fi, holding the unlocked phone, a backup file…)
- steps to reproduce, or a proof of concept

Don't attach real backups or financial data. Use made-up entries.

You'll get a reply within 7 days. Once a fix is released, the advisory is published and credits you, unless you'd rather stay anonymous.

## Scope

How the app protects data (the encrypted database, app lock, backups and sync) is described in [Privacy and security](README.md#privacy-and-security).

In scope, for example:
- reading or changing data without the PIN, the backup password or a completed pairing
- a sync message being read, forged or replayed
- a backup that leaks data, or a crafted backup that harms the app when imported
- the app ever writing the database unencrypted

Already documented, so not a vulnerability on its own:
- others on the same Wi-Fi seeing discovery announcements, device IDs, and the timing and size of sync messages (never their contents)
- importing older, unencrypted backup files
- someone who already controls the device: root access, an unlocked keyring, or malware with the app's own permissions
