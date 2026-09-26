import 'dart:async';

import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import '../data/finance_tools.dart';

/// One streamed fragment of an assistant reply.
class AssistantEvent {
  final String text; // appended to the visible bubble
  final bool isToolStatus; // transient "looking up…" line, not part of answer
  const AssistantEvent(this.text, {this.isToolStatus = false});
}

/// Owns the on-device llama.cpp engine. Downloads a small GGUF model into the
/// package-managed cache on first use, then runs streaming chat with a bounded
/// tool-dispatch loop against [FinanceTools]. Fully offline once loaded.
class OnDeviceLlm {
  static final OnDeviceLlm instance = OnDeviceLlm._();
  OnDeviceLlm._();

  /// Qwen2.5-1.5B-Instruct Q4_K_M (~0.9 GB) — fits in ~3 GB of free phone RAM
  /// and handles simple function calling reliably.
  static const modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';

  LlamaEngine? _engine;
  ChatSession? _session;
  final FinanceTools _tools = FinanceTools();
  Future<void>? _loadFuture;

  bool get isLoaded => _engine?.isReady ?? false;

  /// Download/load progress (0..1). Set by the UI before triggering a load.
  void Function(double fraction)? onProgress;

  /// Ensures the model is downloaded and loaded. Safe to call repeatedly.
  Future<void> ensureLoaded() {
    _loadFuture ??= _doLoad();
    return _loadFuture!;
  }

  Future<void> _doLoad() async {
    if (_engine?.isReady ?? false) return;
    try {
      // Pin the model into app documents storage so it survives in-place
      // updates and is never swept by OS temp cleanup (the default Android
      // location, /data/data/<pkg>/tmp, gets wiped on uninstall).
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheDir = '${docsDir.path}/llama_models';
      final engine = LlamaEngine(
        LlamaBackend(),
        modelDownloadManager: DefaultModelDownloadManager(
          defaultCacheDirectory: cacheDir,
        ),
      );
      onProgress?.call(0.0);
      await engine.loadModelSource(
        ModelSource.url(Uri.parse(modelUrl)),
        modelParams: const ModelParams(contextSize: 4096),
        onProgress: (p) {
          final f = p.fraction;
          if (f != null) onProgress?.call(f.clamp(0.0, 0.9));
        },
      );
      _engine = engine;
      _session = ChatSession(engine, systemPrompt: FinanceTools.systemPrompt);
      onProgress?.call(1.0);
    } catch (e) {
      _loadFuture = null; // allow retry after failure
      rethrow;
    }
  }

  /// Sends [userText] and streams reply fragments plus tool-status lines.
  Stream<AssistantEvent> ask(String userText) async* {
    await ensureLoaded();
    final session = _session!;
    yield* _runTurn(session, parts: [LlamaTextContent(userText)]);
  }

  Stream<AssistantEvent> _runTurn(ChatSession session,
      {required List<LlamaContentPart> parts}) async* {
    final tools = _tools.all;
    var sawToolCall = false;

    await for (final chunk in session.create(parts, tools: tools)) {
      if (chunk.choices.isEmpty) continue;
      final delta = chunk.choices.first.delta;

      final text = delta.content;
      if (text != null && text.isNotEmpty) {
        yield AssistantEvent(text);
      }
      if (delta.toolCalls != null && delta.toolCalls!.isNotEmpty) {
        sawToolCall = true;
      }
    }

    if (!sawToolCall) return;

    // create() recorded the assistant's tool-call message in history.
    // Execute each recorded call, feed results back, then continue.
    final lastMsg = session.history.last;
    final calls = <({String name, Map<String, dynamic> args})>[];
    for (final part in lastMsg.parts) {
      if (part is LlamaToolCallContent) {
        calls.add((name: part.name, args: part.arguments));
      }
    }

    for (final call in calls) {
      yield AssistantEvent('… ${call.name}', isToolStatus: true);
      Object result;
      try {
        final def = tools.firstWhere((t) => t.name == call.name);
        result = await def.handler(ToolParams(call.args)) ?? 'ok';
      } catch (e) {
        result = 'error: $e';
      }
      session.addMessage(LlamaChatMessage.withContent(
        role: LlamaChatRole.tool,
        content: [LlamaToolResultContent(name: call.name, result: result)],
      ));
    }

    yield* _runTurn(session, parts: []);
  }

  /// Clears conversation history (keeps system prompt).
  void resetConversation() => _session?.reset();

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _session = null;
    _loadFuture = null;
  }
}
