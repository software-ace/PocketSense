import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../l10n/app_localizations.dart';
import '../utils/app_dirs.dart';
import '../utils/spoken_numbers.dart';
import 'speech_engine.dart';

/// Offline speech recognition for Linux, which has no system recognizer:
/// sherpa-onnx runs a small streaming English model on the CPU, fed from the
/// microphone through `record` (which uses PulseAudio/PipeWire's parecord).
class DesktopSpeechEngine implements SpeechEngine {
  DesktopSpeechEngine({String? modelDir, AppLocalizations? l10n})
      : _modelDir = modelDir ?? p.join(linuxDataDir(), 'speech', SpeechModel.name),
        _l = l10n ?? lookupAppLocalizations(const Locale('en'));

  final String _modelDir;
  final AppLocalizations _l;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audio;
  Transcriber? _transcriber;
  void Function(String)? _onWords;
  void Function(bool)? _onListening;

  // Loading the model takes a moment and ~100 MB of RAM, so do it once per run.
  static sherpa.OnlineRecognizer? _recognizer;

  @override
  Future<String?> prepare({void Function(double progress)? onProgress}) async {
    try {
      await SpeechModel.download(_modelDir, onProgress: onProgress);
    } on IOException {
      return _l.voiceModelDownloadFailed;
    }
    try {
      _recognizer ??= SpeechModel.load(_modelDir);
    } catch (e) {
      return _l.voiceCouldntStart('$e');
    }
    return null;
  }

  @override
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(bool listening) onListening,
    required void Function(String sentence) onFinal,
    required void Function(String message) onProblem,
  }) async {
    final recorder = _recorder = AudioRecorder();
    final Stream<Uint8List> audio;
    try {
      audio = await recorder.startStream(
          const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: Transcriber.sampleRate, numChannels: 1));
    } on ProcessException {
      await _end();
      onProblem(_l.voiceNeedsParecord);
      return;
    } catch (e) {
      await _end();
      onProblem(_l.voiceMicOpenFailed('$e'));
      return;
    }
    final t = _transcriber = Transcriber(_recognizer!);
    _onWords = onWords;
    _onListening = onListening;
    onListening(true);
    _audio = audio.listen(
      (chunk) {
        final ended = t.add(chunk);
        onWords(t.text);
        if (!ended) return;
        final sentence = t.text;
        unawaited(_end());
        sentence.isEmpty ? onProblem(_l.voiceDidntCatch) : onFinal(sentence);
      },
      onError: (Object e) {
        unawaited(_end());
        onProblem(_l.voiceMicStopped('$e'));
      },
    );
  }

  @override
  Future<void> stop() async {
    final t = _transcriber;
    if (t == null) return;
    await _audio?.cancel();
    _audio = null;
    t.finish();
    _onWords?.call(t.text);
    await _end();
  }

  @override
  Future<void> cancel() => _end();

  Future<void> _end() async {
    await _audio?.cancel();
    _audio = null;
    _transcriber?.free();
    _transcriber = null;
    final r = _recorder;
    _recorder = null;
    if (r != null) {
      await r.stop();
      await r.dispose();
    }
    _onListening?.call(false);
    _onListening = null;
  }
}

/// PCM16 in, words out: one sentence through a sherpa streaming recognizer.
/// Separate from the mic so it can be tested with recorded audio.
class Transcriber {
  Transcriber(this._recognizer) : _stream = _recognizer.createStream() {
    // Measured: without a second of lead-in the model drops the first words
    // ("after early nightfall the…" → "the…"). Silence decodes instantly.
    _silence(1.0);
  }

  static const sampleRate = 16000;

  final sherpa.OnlineRecognizer _recognizer;
  final sherpa.OnlineStream _stream;
  int? _oddByte; // chunks can split a 16-bit sample in two
  String text = '';

  /// Feeds little-endian 16-bit mono samples. Returns true once the speaker
  /// has stopped (or never started) — see the endpoint rules in [SpeechModel].
  bool add(Uint8List pcm) {
    _stream.acceptWaveform(samples: _toFloat(pcm), sampleRate: sampleRate);
    _decode();
    return _recognizer.isEndpoint(_stream);
  }

  /// No more audio: flush what the model still holds.
  void finish() {
    // Trailing silence lets the last word finish decoding instead of being cut.
    _silence(0.5);
    _stream.inputFinished();
    _decode();
  }

  void free() => _stream.free();

  void _silence(double seconds) =>
      _stream.acceptWaveform(samples: Float32List((sampleRate * seconds).round()), sampleRate: sampleRate);

  void _decode() {
    while (_recognizer.isReady(_stream)) {
      _recognizer.decode(_stream);
    }
    text = normalizeSpokenText(_recognizer.getResult(_stream).text);
  }

  Float32List _toFloat(Uint8List pcm) {
    var bytes = pcm;
    if (_oddByte != null) {
      bytes = Uint8List(pcm.length + 1)
        ..[0] = _oddByte!
        ..setRange(1, pcm.length + 1, pcm);
      _oddByte = null;
    }
    final n = bytes.length ~/ 2;
    if (bytes.length.isOdd) _oddByte = bytes.last;
    final data = ByteData.sublistView(bytes);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    return out;
  }
}

/// The speech model: which files, where they come from, how to load them.
abstract final class SpeechModel {
  static const name = 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17';

  // Pinned to a commit so the files can't change under us; sizes double as
  // an integrity check for interrupted downloads.
  static const _baseUrl = 'https://huggingface.co/csukuangfj/$name/resolve/d42f2d9f7ca24806fb667456a18a9f1b60f70d16';
  static const _files = {
    'encoder-epoch-99-avg-1.int8.onnx': 42845182,
    'decoder-epoch-99-avg-1.onnx': 2092272,
    'joiner-epoch-99-avg-1.int8.onnx': 259572,
    'tokens.txt': 5048,
  };

  static int get totalBytes => _files.values.fold(0, (a, b) => a + b);

  static bool isDownloaded(String dir) =>
      _files.entries.every((f) => File(p.join(dir, f.key)).existsSync() && File(p.join(dir, f.key)).lengthSync() == f.value);

  /// Fetches whatever is missing into [dir]. Each file lands under a .part
  /// name first, so a cut-off download is never mistaken for a finished one.
  static Future<void> download(String dir, {void Function(double progress)? onProgress}) async {
    final missing = _files.entries.where((f) {
      final file = File(p.join(dir, f.key));
      return !file.existsSync() || file.lengthSync() != f.value;
    }).toList();
    if (missing.isEmpty) return;
    await Directory(dir).create(recursive: true);
    final total = missing.fold(0, (a, f) => a + f.value);
    var done = 0;
    final client = HttpClient();
    try {
      for (final f in missing) {
        final res = await (await client.getUrl(Uri.parse('$_baseUrl/${f.key}'))).close();
        if (res.statusCode != HttpStatus.ok) throw HttpException('HTTP ${res.statusCode} for ${f.key}');
        final part = File(p.join(dir, '${f.key}.part'));
        final sink = part.openWrite();
        try {
          await for (final chunk in res) {
            sink.add(chunk);
            done += chunk.length;
            onProgress?.call(done / total);
          }
        } finally {
          await sink.close();
        }
        if (await part.length() != f.value) throw HttpException('Incomplete download of ${f.key}');
        await part.rename(p.join(dir, f.key));
      }
    } finally {
      client.close();
    }
  }

  /// [libDir] overrides where the native library is found; the app bundle's
  /// lib/ is searched by default.
  static sherpa.OnlineRecognizer load(String dir, {String? libDir}) {
    sherpa.initBindings(libDir);
    return sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: p.join(dir, 'encoder-epoch-99-avg-1.int8.onnx'),
          decoder: p.join(dir, 'decoder-epoch-99-avg-1.onnx'),
          joiner: p.join(dir, 'joiner-epoch-99-avg-1.int8.onnx'),
        ),
        tokens: p.join(dir, 'tokens.txt'),
        numThreads: 2,
        debug: false,
      ),
      // Endpoint rules, matched to the Android recognizer's feel: give up
      // after 5 s of silence with nothing said (6 s including the Transcriber's
      // 1 s lead-in); end the sentence after a 2 s pause; cap it at 30 s.
      rule1MinTrailingSilence: 6.0,
      rule2MinTrailingSilence: 2.0,
      rule3MinUtteranceLength: 30,
    ));
  }
}
