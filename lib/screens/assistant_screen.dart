import 'dart:async';

import 'package:flutter/material.dart';

import '../ai/on_device_llm.dart';
import 'settings_screen.dart';

class _Bubble {
  final int index;
  final String text;
  final bool isUser;
  _Bubble(this.index, this.text, this.isUser);
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _llm = OnDeviceLlm.instance;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<AssistantEvent>? _sub;

  List<_Bubble> _bubbles = [];
  String? _toolStatus;
  double? _progress; // null = not downloading/loading
  Object? _loadError;
  bool _busy = false;

  static const _suggestions = [
    'How much did I spend this month?',
    'Where does my money go most?',
    'Am I over any budgets?',
    'Log \$8.50 coffee at Blue Bottle',
  ];

  @override
  void initState() {
    super.initState();
    // Warm up lazily: a ~0.9 GB download on tab-open would surprise the user.
    // The first question triggers the load and shows progress inline.
  }

  Future<void> _ensureReady() async {
    if (_llm.isLoaded || _progress != null) return;
    setState(() => _progress = 0.0);
    _llm.onProgress = (f) {
      if (mounted) setState(() => _progress = f);
    };
    try {
      await _llm.ensureLoaded();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _progress = null;
        });
      }
      rethrow;
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;
    try {
      await _ensureReady();
    } catch (_) {
      return; // load error surfaced by _ensureReady
    }
    _controller.clear();
    final idx = _bubbles.length;
    setState(() {
      _bubbles.add(_Bubble(idx, text, true));
      _bubbles.add(_Bubble(idx + 1, '', false));
      _busy = true;
      _toolStatus = null;
    });
    _scrollToEnd();

    _sub?.cancel();
    _sub = _llm.ask(text).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          final b = _bubbles[idx + 1];
          if (event.isToolStatus) {
            _toolStatus = event.text;
          } else {
            _bubbles[idx + 1] = _Bubble(idx + 1, b.text + event.text, false);
          }
        });
        _scrollToEnd();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          final b = _bubbles[idx + 1];
          _bubbles[idx + 1] = _Bubble(
              idx + 1,
              b.text.isEmpty ? 'Sorry, something went wrong: $e' : b.text,
              false);
          _busy = false;
          _toolStatus = null;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _toolStatus = null;
        });
        _scrollToEnd();
      },
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _bubbles.isEmpty
                ? null
                : () {
                    _llm.resetConversation();
                    setState(() {
                      _bubbles = [];
                      _toolStatus = null;
                    });
                  },
          ),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          if (_progress != null && !_llm.isLoaded) ...[
            LinearProgressIndicator(minHeight: 3, value: _progress),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _progress! < 1
                    ? 'Downloading offline model… ${( _progress! * 100).toStringAsFixed(0)}%'
                    : 'Loading model…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          Expanded(
            child: _bubbles.isEmpty
                ? _emptyState(scheme)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _bubbles.length + (_toolStatus != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_toolStatus != null && i == _bubbles.length) {
                        return Center(
                          child: Chip(
                            avatar: const SizedBox(
                                width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            label: Text(_toolStatus!),
                          ),
                        );
                      }
                      final b = _bubbles[i];
                      return _bubble(b, scheme);
                    },
                  ),
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Model unavailable: ${_loadError.toString().split('\n').first}',
                    style: TextStyle(fontSize: 12, color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _loadError = null;
                  }),
                  child: const Text('Dismiss'),
                ),
              ]),
            ),
          _inputBar(scheme),
        ],
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 24),
            child: Column(
              children: [
                Icon(Icons.psychology_alt_rounded,
                    size: 56, color: scheme.primary.withValues(alpha: .6)),
                const SizedBox(height: 12),
                Text('Ask about your money',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Runs fully offline on your phone.\nIt can read your transactions, budgets and spending — and log new ones.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(s, style: const TextStyle(fontSize: 14)),
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: scheme.outline),
                onTap: () {
                  unawaited(_send(s));
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _bubble(_Bubble b, ColorScheme scheme) {
    final isUser = b.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(isUser ? 18 : 6),
        ),
        child: Text(
          b.text,
          style: TextStyle(
              fontSize: 15,
              color: isUser ? scheme.onPrimaryContainer : scheme.onSurface),
        ),
      ),
    );
  }

  Widget _inputBar(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about your spending…',
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _busy ? null : () => _send(),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
