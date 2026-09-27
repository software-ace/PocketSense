import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/sync_reconcile.dart';

void main() {
  group('planReconcile', () {
    test('fetches rows missing locally or with a different updated_at', () {
      final plan = planReconcile(
        local: {1: '2026-09-01T00:00:00Z', 2: '2026-09-01T00:00:00Z'},
        remote: {1: '2026-09-01T00:00:00Z', 2: '2026-09-02T00:00:00Z', 3: '2026-09-02T00:00:00Z'},
        pendingIds: {},
      );
      expect(plan.toFetch, unorderedEquals([2, 3]));
      expect(plan.toDeleteLocally, isEmpty);
    });

    test('treats Z and +00:00 as the same instant', () {
      final plan = planReconcile(
        local: {1: '2026-09-27T16:49:06.537595Z'},
        remote: {1: '2026-09-27T16:49:06.537595+00:00'},
        pendingIds: {},
      );
      expect(plan.toFetch, isEmpty);
    });

    test('deletes local rows the server no longer has', () {
      final plan = planReconcile(
        local: {1: 'a', 12: 'b'},
        remote: {1: 'a'},
        pendingIds: {},
      );
      expect(plan.toDeleteLocally, [12]);
    });

    test('never deletes a row still waiting in the outbox', () {
      final plan = planReconcile(
        local: {1: 'a', 99: 'new'},
        remote: {1: 'a'},
        pendingIds: {99},
      );
      expect(plan.toDeleteLocally, isEmpty);
    });
  });
}
