import 'dart:io';

import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/app_localizations.dart';
import 'desktop_speech_engine.dart';

/// Hears one spoken sentence at a time. The voice sheet drives it and doesn't
/// care which recognizer is underneath.
abstract class SpeechEngine {
  /// Whatever [listen] needs first: mic permission, a model download.
  /// [onProgress] reports a download from 0 to 1. Returns a message for the
  /// user if listening can't work, or null when ready.
  Future<String?> prepare({void Function(double progress)? onProgress});

  /// Start hearing. [onWords] gets the running transcript, [onListening] the
  /// mic state. When the speaker stops on their own, [onFinal] fires with the
  /// sentence — or [onProblem] with a message if nothing usable was heard.
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(bool listening) onListening,
    required void Function(String sentence) onFinal,
    required void Function(String message) onProblem,
  });

  /// Stop now. The last [onWords] before this returns is the full sentence.
  Future<void> stop();

  /// Stop and discard.
  Future<void> cancel();
}

/// Android uses the phone's recognizer; Linux uses the bundled offline model.
bool get voiceEntrySupported => Platform.isAndroid || Platform.isLinux;

/// [l10n] words the problems an engine reports to the user.
SpeechEngine createSpeechEngine(AppLocalizations l10n) =>
    Platform.isAndroid ? AndroidSpeechEngine(l10n) : DesktopSpeechEngine(l10n: l10n);

/// The phone's own recognizer, through speech_to_text.
class AndroidSpeechEngine implements SpeechEngine {
  AndroidSpeechEngine(this._l);

  final AppLocalizations _l;

  // One recognizer for the app; initialize() is only allowed to succeed once.
  static final SpeechToText _speech = SpeechToText();

  void Function(bool)? _onListening;
  void Function(String)? _onProblem;

  @override
  Future<String?> prepare({void Function(double progress)? onProgress}) async {
    // The first call shows Android's microphone permission prompt.
    final ok = await _speech.initialize(
      onStatus: (s) => _onListening?.call(s == SpeechToText.listeningStatus),
      onError: (e) {
        _onListening?.call(false);
        _onProblem?.call(switch (e.errorMsg) {
          'error_no_match' || 'error_speech_timeout' => _l.voiceDidntCatch,
          'error_permission' => _l.voiceMicPermissionOff,
          'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' ||
          'error_language_not_supported' || 'error_language_unavailable' =>
            _l.voiceNeedsConnection,
          _ => _l.voiceFailed(e.errorMsg),
        });
      },
    );
    if (ok) return null;
    return await _speech.hasPermission ? _l.voiceUnavailable : _l.voiceMicPermissionOff;
  }

  @override
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(bool listening) onListening,
    required void Function(String sentence) onFinal,
    required void Function(String message) onProblem,
  }) async {
    _onListening = onListening;
    _onProblem = onProblem;
    await _speech.listen(
      onResult: (r) {
        onWords(r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) onFinal(r.recognizedWords.trim());
      },
      listenOptions: SpeechListenOptions(
        // The sentence parser understands English only, so ask for English
        // even on a phone set to Arabic.
        localeId: 'en_US',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }
}
