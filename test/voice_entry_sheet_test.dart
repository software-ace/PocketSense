import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/voice/speech_engine.dart';
import 'package:pocket_sense/widgets/voice_entry_sheet.dart';

import 'helpers/localized_app.dart';

/// Scripted recognizer: the test decides when words arrive and how it ends.
class FakeEngine implements SpeechEngine {
  final calls = <String>[];
  String? prepareProblem;
  Completer<void>? downloadGate;
  void Function(double)? progress;
  late void Function(String) words;
  late void Function(bool) listening;
  late void Function(String) finalSentence;
  late void Function(String) problem;

  @override
  Future<String?> prepare({void Function(double progress)? onProgress}) async {
    calls.add('prepare');
    progress = onProgress;
    await downloadGate?.future;
    return prepareProblem;
  }

  @override
  Future<void> listen({
    required void Function(String words) onWords,
    required void Function(bool listening) onListening,
    required void Function(String sentence) onFinal,
    required void Function(String message) onProblem,
  }) async {
    calls.add('listen');
    words = onWords;
    listening = onListening;
    finalSentence = onFinal;
    problem = onProblem;
    onListening(true);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  late FakeEngine engine;
  late String? result;
  setUp(() {
    engine = FakeEngine();
    result = 'not closed';
  });

  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(localizedApp(
      Builder(
        builder: (c) => TextButton(onPressed: () async => result = await showVoiceEntrySheet(c, engine: engine), child: const Text('open')),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows download progress, then listens', (t) async {
    engine.downloadGate = Completer();
    await open(t);
    engine.progress!(0.4);
    await t.pump();
    expect(find.text('Downloading speech model…'), findsOneWidget);
    expect(t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.4);
    expect(find.textContaining('One-time download'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull, reason: 'nothing to do mid-download');

    engine.downloadGate!.complete();
    await t.pump();
    expect(find.text('Listening…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows words as they arrive and returns the final sentence', (t) async {
    await open(t);
    engine.words('spent 12.50');
    await t.pump();
    expect(find.text('"spent 12.50"'), findsOneWidget);
    engine.finalSentence('spent 12.50 on lunch');
    await t.pumpAndSettle();
    expect(result, 'spent 12.50 on lunch');
  });

  testWidgets('Done stops early and returns what was heard', (t) async {
    await open(t);
    engine.words('paid 40 for gas');
    await t.pump();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(engine.calls, contains('stop'));
    expect(result, 'paid 40 for gas');
  });

  testWidgets('Cancel discards and returns nothing', (t) async {
    await open(t);
    engine.words('never mind');
    await t.pump();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(engine.calls, contains('cancel'));
  });

  testWidgets('a problem is shown, and Try again starts over', (t) async {
    engine.prepareProblem = "Couldn't download the speech model. Check your connection and try again.";
    await open(t);
    expect(find.textContaining("Couldn't download the speech model"), findsOneWidget);
    expect(engine.calls, ['prepare']);

    engine.prepareProblem = null;
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(engine.calls, ['prepare', 'prepare', 'listen']);
    expect(find.text('Listening…'), findsOneWidget);
  });

  testWidgets('a problem while listening is shown', (t) async {
    await open(t);
    engine.problem("Didn't catch that. Tap the mic and try again.");
    await t.pump();
    expect(find.text("Didn't catch that. Tap the mic and try again."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
