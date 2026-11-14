## What and why

<!-- What does this change, and why? Link the issue it closes: "Closes #12". -->

## How you tested it

<!-- Which platforms you ran it on (Android, Linux), and what you checked by hand. -->

## Screenshots

<!-- For UI changes: before and after, in English and Arabic (right-to-left). Use the demo data in docs/demo-backup.json, never your own. -->

**Needs new README or F-Droid screenshots?** No / Yes: <!-- which screens -->

## Checklist

- [ ] `flutter analyze` and `flutter test` pass
- [ ] Tests added or updated for changed behavior
- [ ] New strings are in both `app_en.arb` and `app_ar.arb`, and the `flutter gen-l10n` output is committed
- [ ] Money stays integer fils, never doubles
- [ ] A schema change bumps `schemaVersion` with an `onUpgrade` step
- [ ] No new network connections; the app stays offline
- [ ] Any new dependency is open source, with no Google services or tracking (F-Droid builds from source)
- [ ] README updated if users or contributors would notice the change
- [ ] Version, changelogs, and release notes left untouched; the maintainer handles those
