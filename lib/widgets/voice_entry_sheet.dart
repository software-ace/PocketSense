import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// speech_to_text supports Android here, not Linux, so callers hide the mic.
bool get voiceEntrySupported => Platform.isAndroid;

// One recognizer for the app; initialize() is only allowed to succeed once.
final SpeechToText _speech = SpeechToText();

/// Listens for one spoken sentence and returns what was heard, or null if
/// the user cancelled or nothing was recognized.
Future<String?> showVoiceEntrySheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _VoiceEntrySheet(),
    );

class _VoiceEntrySheet extends StatefulWidget {
  const _VoiceEntrySheet();

  @override
  State<_VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<_VoiceEntrySheet> {
  String _heard = '';
  String? _problem;
  bool _listening = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    if (_speech.isListening) _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _problem = null;
      _heard = '';
      _done = false;
    });
    // The first call shows Android's microphone permission prompt.
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (!mounted) return;
        setState(() => _listening = s == SpeechToText.listeningStatus);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _problem = switch (e.errorMsg) {
            'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Tap the mic and try again.",
            'error_permission' => 'Microphone permission is off. Allow it in Settings → Apps → Pocket Sense.',
            'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' ||
            'error_language_not_supported' || 'error_language_unavailable' =>
              'Speech recognition needs a connection on this phone, or an offline speech pack for your language.',
            _ => 'Speech recognition failed (${e.errorMsg}).',
          };
        });
      },
    );
    if (!mounted) return;
    if (!ok) {
      final permitted = await _speech.hasPermission;
      if (!mounted) return;
      setState(() => _problem = permitted
          ? "Speech recognition isn't available on this phone."
          : 'Microphone permission is off. Allow it in Settings → Apps → Pocket Sense.');
      return;
    }
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty && !_done) {
          _done = true;
          Navigator.pop(context, r.recognizedWords.trim());
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _finish() async {
    await _speech.stop();
    if (!mounted || _done) return;
    _done = true;
    Navigator.pop(context, _heard.trim().isEmpty ? null : _heard.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_listening ? 'Listening…' : (_problem == null ? 'Starting…' : 'Voice entry'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _listening ? _finish : _start,
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
            Text('Try: "Spent 12.50 on lunch at Subway"\n"Received 500 from Acme yesterday"',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _listening || _heard.isNotEmpty ? _finish : _start,
                child: Text(_listening || _heard.isNotEmpty ? 'Done' : 'Try again'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
