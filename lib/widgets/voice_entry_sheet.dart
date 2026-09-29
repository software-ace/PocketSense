import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../voice/desktop_speech_engine.dart' show SpeechModel;
import '../voice/speech_engine.dart';

export '../voice/speech_engine.dart' show voiceEntrySupported;

/// Listens for one spoken sentence and returns what was heard, or null if
/// the user cancelled or nothing was recognized.
Future<String?> showVoiceEntrySheet(BuildContext context, {SpeechEngine? engine}) => showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _VoiceEntrySheet(engine ?? createSpeechEngine(context.l10n)),
    );

class _VoiceEntrySheet extends StatefulWidget {
  const _VoiceEntrySheet(this.engine);

  final SpeechEngine engine;

  @override
  State<_VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<_VoiceEntrySheet> {
  String _heard = '';
  String? _problem;
  double? _download; // 0–1 while the speech model downloads, else null
  bool _listening = false;
  bool _done = false;

  SpeechEngine get _engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    if (!_done) _engine.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _problem = null;
      _heard = '';
      _done = false;
    });
    final problem = await _engine.prepare(onProgress: (v) {
      if (mounted) setState(() => _download = v);
    });
    if (!mounted) return;
    setState(() {
      _download = null;
      _problem = problem;
    });
    if (problem != null) return;
    await _engine.listen(
      onWords: (w) {
        if (mounted) setState(() => _heard = w);
      },
      onListening: (l) {
        if (mounted) setState(() => _listening = l);
      },
      onFinal: (sentence) {
        if (!mounted || _done) return;
        _done = true;
        Navigator.pop(context, sentence);
      },
      onProblem: (message) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _problem = message;
        });
      },
    );
  }

  Future<void> _finish() async {
    await _engine.stop();
    if (!mounted || _done) return;
    _done = true;
    Navigator.pop(context, _heard.trim().isEmpty ? null : _heard.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    // Scrolls rather than overflows: sheets are capped at 9/16 of the window,
    // and a short desktop window can't fit the download state.
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_download != null ? l.voiceDownloading : _listening ? l.voiceListening : (_problem == null ? l.voiceStarting : l.voiceTitle),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            if (_download != null) ...[
              LinearProgressIndicator(value: _download),
              const SizedBox(height: 12),
              Text(l.voiceDownloadNote((SpeechModel.totalBytes / 1e6).round()),
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
              const SizedBox(height: 20),
            ],
            GestureDetector(
              onTap: _download != null ? null : (_listening ? _finish : _start),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _listening ? 88 : 72,
                height: _listening ? 88 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? scheme.primary : scheme.surfaceContainerHighest,
                  boxShadow: _listening ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)] : null,
                ),
                child: Icon(_listening ? Icons.mic : Icons.mic_none, size: 36, color: _listening ? scheme.onPrimary : scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            if (_problem != null)
              Text(_problem!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))
            else if (_heard.isNotEmpty)
              Text('"$_heard"', textAlign: TextAlign.center, style: theme.textTheme.titleMedium)
            else
              Text(l.voiceHint,
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _download != null ? null : (_listening || _heard.isNotEmpty ? _finish : _start),
                  child: Text(_listening || _heard.isNotEmpty ? l.done : l.tryAgain),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
