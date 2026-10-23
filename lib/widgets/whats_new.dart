import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../settings/app_settings.dart';

/// This build's number (the "+N" in pubspec.yaml), or null in builds
/// without one, like tests.
final int? currentBuild = int.tryParse(const String.fromEnvironment('FLUTTER_BUILD_NUMBER'));

enum ChangeKind { other, feature, improvement, change, fix }

// A changelog line's first word says which heading it goes under.
const _tags = {
  ChangeKind.feature: ['new', 'جديد'],
  ChangeKind.improvement: ['improved', 'تحسين'],
  ChangeKind.change: ['changed', 'تغيير'],
  ChangeKind.fix: ['fixed', 'إصلاح'],
};

/// One changelog's lines by kind: "• Fixed: …" is a fix, and so on; a line
/// without a tag is [ChangeKind.other].
Map<ChangeKind, List<String>> parseChangelog(String text) {
  final out = <ChangeKind, List<String>>{};
  for (var line in const LineSplitter().convert(text)) {
    line = line.replaceFirst(RegExp(r'^\s*[•*-]\s*'), '').trim();
    if (line.isEmpty) continue;
    var kind = ChangeKind.other;
    for (final e in _tags.entries) {
      final tag = RegExp('^(?:${e.value.join('|')})\\s*:\\s*', caseSensitive: false).firstMatch(line);
      if (tag != null) {
        kind = e.key;
        line = line.substring(tag.end);
        break;
      }
    }
    if (line.isNotEmpty) out.putIfAbsent(kind, () => []).add(line[0].toUpperCase() + line.substring(1));
  }
  return out;
}

/// Once per update: what changed since the build last opened. The text is
/// the F-Droid changelogs (`fastlane/…/changelogs/<N>2.txt`), bundled as
/// assets, so a release writes it once for both.
Future<void> showWhatsNewIfUpdated(BuildContext context, {int? build}) async {
  final current = build ?? currentBuild;
  if (current == null) return;
  final seen = AppSettings.whatsNewSeen;
  if (seen != null && seen >= current) return;
  await AppSettings.setWhatsNewSeen(current);
  if (!context.mounted) return;

  // Installs from before this existed: just this version's changes.
  final since = seen ?? current - 1;
  final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en-US';
  final file = RegExp('^fastlane/metadata/android/$lang/changelogs/(\\d+)2\\.txt\$');
  final assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
  final builds = {for (final a in assets) if (file.firstMatch(a) case final m?) int.parse(m.group(1)!): a};
  final groups = <ChangeKind, List<String>>{};
  for (final n in builds.keys.where((n) => n > since && n <= current).toList()..sort((a, b) => b - a)) {
    parseChangelog(await rootBundle.loadString(builds[n]!)).forEach((k, v) => groups.putIfAbsent(k, () => []).addAll(v));
  }
  if (groups.isEmpty || !context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => WhatsNewDialog(groups: groups));
}

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key, required this.groups});

  final Map<ChangeKind, List<String>> groups;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final headings = {
      ChangeKind.feature: l.whatsNewFeatures,
      ChangeKind.improvement: l.whatsNewImprovements,
      ChangeKind.change: l.whatsNewChanges,
      ChangeKind.fix: l.whatsNewFixes,
    };
    return AlertDialog(
      title: Text(l.whatsNewTitle(const String.fromEnvironment('FLUTTER_BUILD_NAME'))),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          for (final kind in ChangeKind.values)
            if (groups[kind] case final lines? when lines.isNotEmpty) ...[
              if (headings[kind] case final heading?)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(heading, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  '),
                    Expanded(child: Text(line)),
                  ]),
                ),
            ],
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.done))],
    );
  }
}
