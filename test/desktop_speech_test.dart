import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_sense/voice/desktop_speech_engine.dart';

/// Runs the real Linux speech model. Opt-in, since the first run downloads
/// ~45 MB: SPEECH_MODEL_DIR=/some/dir flutter test test/desktop_speech_test.dart
void main() {
  final dir = Platform.environment['SPEECH_MODEL_DIR'];
  final skip = dir == null || !Platform.isLinux ? 'set SPEECH_MODEL_DIR (Linux only) to run' : null;

  /// 16 kHz mono 16-bit samples from a WAV file's "data" chunk.
  Uint8List wavPcm(File f) {
    final b = f.readAsBytesSync();
    final d = ByteData.sublistView(b);
    var i = 12;
    while (i + 8 <= b.length) {
      final id = String.fromCharCodes(b.sublist(i, i + 4));
      final size = d.getUint32(i + 4, Endian.little);
      if (id == 'data') return b.sublist(i + 8, i + 8 + size);
      i += 8 + size + (size.isOdd ? 1 : 0);
    }
    throw FormatException('no data chunk in ${f.path}');
  }

  test('downloads the model, then transcribes speech fed in mic-sized chunks', () async {
    final modelDir = dir!;
    var last = 0.0;
    await SpeechModel.download(modelDir, onProgress: (v) => last = v);
    expect(SpeechModel.isDownloaded(modelDir), isTrue);
    expect(last == 0.0 || last == 1.0, isTrue, reason: 'progress ends at 100% (or nothing to fetch)');

    final wav = File(p.join(modelDir, 'test_0.wav'));
    if (!wav.existsSync()) {
      final client = HttpClient();
      final res = await (await client.getUrl(Uri.parse(
              'https://huggingface.co/csukuangfj/${SpeechModel.name}/resolve/d42f2d9f7ca24806fb667456a18a9f1b60f70d16/test_wavs/0.wav')))
          .close();
      await res.pipe(wav.openWrite());
      client.close();
    }

    // Outside an app bundle, point sherpa at the plugin's own copy.
    final pkgs = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())['packages'] as List;
    final linuxPkg = pkgs.firstWhere((e) => e['name'] == 'sherpa_onnx_linux')['rootUri'] as String;
    final libDir = p.join(Uri.parse(linuxPkg).toFilePath(), 'linux', 'x64');
    final t = Transcriber(SpeechModel.load(modelDir, libDir: libDir));
    final pcm = wavPcm(wav);
    // 100 ms chunks, and an odd split to exercise the carried-over byte.
    const chunk = 3201;
    final sw = Stopwatch()..start();
    for (var i = 0; i < pcm.length; i += chunk) {
      t.add(Uint8List.sublistView(pcm, i, (i + chunk).clamp(0, pcm.length)));
    }
    t.finish();
    sw.stop();
    t.free();

    final audioMs = pcm.length / 2 / Transcriber.sampleRate * 1000;
    // ignore: avoid_print
    print('"${t.text}"  (${sw.elapsedMilliseconds} ms for ${audioMs.round()} ms of audio)');
    // Reference: "after early nightfall the yellow lamps would light up here
    // and there the squalid quarter of the brothels". The 20M model misses the
    // rare last word; the opening words are what the lead-in protects.
    expect(t.text, startsWith('after early nightfall the yellow lamps would light up here and there'));
    expect(sw.elapsedMilliseconds, lessThan(audioMs), reason: 'must keep up with live audio');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));
}
