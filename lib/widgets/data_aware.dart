import 'package:flutter/widgets.dart';

import '../data/local_store.dart';

/// Reloads a tab whenever local data changes. Tabs sit in an IndexedStack, so
/// without this a transaction added on one tab would leave the others stale.
mixin DataAware<T extends StatefulWidget> on State<T> {
  void onDataChanged();

  ValueNotifier<int>? _changes;

  void _listener() {
    if (mounted) onDataChanged();
  }

  @override
  void initState() {
    super.initState();
    LocalStore.instance().then((s) {
      if (!mounted) return;
      _changes = s.changes..addListener(_listener);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _changes?.removeListener(_listener);
    super.dispose();
  }
}
