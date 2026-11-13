import '../utils/csv.dart';
import '../utils/format.dart';
import 'local_store.dart';
import 'repo.dart';

/// What a CSV file holds.
enum CsvKind { transactions, categories, merchants }

/// What importing does with one row.
enum CsvVerdict { add, duplicate, rejected }

/// A CSV file without the columns its kind needs. Nothing can be previewed.
class CsvLayoutException implements Exception {
  CsvLayoutException(this.missing);

  /// Required columns the header doesn't have.
  final List<String> missing;

  @override
  String toString() => 'CsvLayoutException(missing: $missing)';
}

/// One row of a file, as the preview shows it.
class PreviewRow {
  PreviewRow({required this.row, required this.values, required this.verdict, this.problem, this.insert, this.newMerchant, this.unknownAccount = false});

  /// Its row number in the file; the header is row 1.
  final int row;

  /// Its cells by column name, trimmed.
  final Map<String, String> values;
  final CsvVerdict verdict;

  /// For a rejected row, the column at fault.
  final String? problem;

  /// For a row to add, what importing writes.
  final Map<String, Object?>? insert;

  /// A transaction's merchant that isn't in the list yet: importing saves it.
  final String? newMerchant;

  /// A transaction's account that isn't one of yours: it goes into the
  /// default account.
  final bool unknownAccount;

  String operator [](String column) => values[column] ?? '';
}

class CsvPreview {
  CsvPreview(this.kind, this.rows);
  final CsvKind kind;
  final List<PreviewRow> rows;
  int count(CsvVerdict v) => rows.where((r) => r.verdict == v).length;
}

/// What an import did. The last three are for transactions only (0 otherwise).
typedef ImportSummary = ({int added, int duplicates, int rejected, int categoriesMatched, int newMerchants, int uncategorized, int unknownAccounts});

/// Settings → Data and the Categories and Merchants screens: Pocket Sense's
/// own CSV layouts. Export writes them; import reads the same columns (by
/// name, in any order, extra ones ignored), shows what it would do with each
/// row, and only ever adds.
abstract final class CsvFiles {
  static const columns = {
    CsvKind.transactions: ['date', 'type', 'amount', 'description', 'category', 'merchant', 'account'],
    CsvKind.categories: ['name', 'type', 'color'],
    CsvKind.merchants: ['name'],
  };
  static const _required = {
    CsvKind.transactions: ['date', 'type', 'amount', 'description'],
    CsvKind.categories: ['name', 'type'],
    CsvKind.merchants: ['name'],
  };

  static const _defaultCategoryColor = '#64748b';
  static const _types = {'income', 'expense'};

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [s] as a date if it's exactly yyyy-MM-dd and a real day, else null.
  static DateTime? parseDate(String s) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return null;
    final d = DateTime.tryParse(s);
    // DateTime.parse rolls 2026-02-30 over into March; that's a typo, not a date.
    return d != null && _iso(d) == s ? d : null;
  }

  // ── Export ───────────────────────────────────────────────────────────

  static Future<String> export(CsvKind kind) async {
    final repo = FinanceRepo();
    return encodeCsv([
      columns[kind]!,
      ...switch (kind) {
        // Oldest first, as a statement reads. Transfers aren't entries, so
        // they aren't here.
        CsvKind.transactions => await () async {
            final accounts = {for (final a in await repo.accounts()) a.id: a.name};
            return [
              for (final t in (await repo.transactions(limit: 1 << 30))..sort((a, b) => a.date.compareTo(b.date)))
                [_iso(t.date), t.type, amountToInput(t.amountFils), t.description, t.categoryName ?? '', t.merchant ?? '', accounts[t.accountId] ?? ''],
            ];
          }(),
        CsvKind.categories => [for (final c in await repo.categories()) [c.name, c.type, c.color]],
        CsvKind.merchants => [for (final m in await repo.merchants()) [m.name]],
      },
    ]);
  }

  // ── Preview ──────────────────────────────────────────────────────────

  /// Reads every row and judges it, writing nothing. Throws
  /// [CsvLayoutException] only when required columns are missing.
  static Future<CsvPreview> preview(CsvKind kind, String text) async {
    final all = decodeCsv(text);
    final header = [for (final h in all.firstOrNull ?? const <String>[]) h.trim().toLowerCase()];
    final missing = [for (final c in _required[kind]!) if (!header.contains(c)) c];
    if (missing.isNotEmpty) throw CsvLayoutException(missing);
    final rows = [
      for (final r in all.skip(1)) {for (final (i, h) in header.indexed) h: i < r.length ? r[i].trim() : ''},
    ];
    return CsvPreview(kind, switch (kind) {
      CsvKind.transactions => await _transactions(rows),
      CsvKind.categories => await _names(rows, {for (final c in await FinanceRepo().categories()) c.name}, _category),
      CsvKind.merchants => await _names(rows, {for (final m in await FinanceRepo().merchants()) m.name}, _merchant),
    });
  }

  /// Of each date, type, amount and description, as many as already exist
  /// are duplicates: importing a file twice adds nothing, while two real
  /// coffees on one day both stay. A category is matched by name and type;
  /// one you don't have leaves the entry uncategorized.
  static Future<List<PreviewRow>> _transactions(List<Map<String, String>> rows) async {
    final repo = FinanceRepo();
    String key(String date, String type, int fils, String description) => '$date|$type|$fils|$description';
    final have = <String, int>{};
    for (final t in await repo.transactions(limit: 1 << 30)) {
      have.update(key(_iso(t.date), t.type, t.amountFils, t.description), (n) => n + 1, ifAbsent: () => 1);
    }
    final categories = {for (final c in await repo.categories()) '${c.type}/${c.name.toLowerCase()}': c.id};
    final merchants = {for (final m in await repo.merchants()) m.name.toLowerCase()};
    // By name, open accounts first; empty or unknown: the default account.
    final accounts = <String, int>{};
    for (final a in await repo.accounts()) {
      accounts.putIfAbsent(a.name.toLowerCase(), () => a.id);
    }
    final defaultAccount = await repo.defaultAccountId();
    final now = LocalStore.nowIso();

    return [
      for (final (i, r) in rows.indexed)
        () {
          final type = r['type']!.toLowerCase();
          final fils = parseAmount(r['amount']!);
          final problem = parseDate(r['date']!) == null
              ? 'date'
              : !_types.contains(type)
                  ? 'type'
                  : fils == null || fils <= 0
                      ? 'amount'
                      : null;
          if (problem != null) return PreviewRow(row: i + 2, values: r, verdict: CsvVerdict.rejected, problem: problem);
          final k = key(r['date']!, type, fils!, r['description']!);
          final n = have[k] ?? 0;
          if (n > 0) {
            have[k] = n - 1;
            return PreviewRow(row: i + 2, values: r, verdict: CsvVerdict.duplicate);
          }
          final category = r['category'] ?? '', merchant = r['merchant'] ?? '', account = r['account'] ?? '';
          final accountId = accounts[account.toLowerCase()];
          return PreviewRow(
            row: i + 2,
            values: r,
            verdict: CsvVerdict.add,
            insert: {
              'amount_fils': fils,
              'type': type,
              'date': r['date'],
              'description': r['description'],
              'merchant': merchant.isEmpty ? null : merchant,
              'category_id': category.isEmpty ? null : categories['$type/${category.toLowerCase()}'],
              'account_id': accountId ?? defaultAccount,
              'created_at': now,
            },
            newMerchant: merchant.isNotEmpty && !merchants.contains(merchant.toLowerCase()) ? merchant : null,
            unknownAccount: account.isNotEmpty && accountId == null,
          );
        }(),
    ];
  }

  /// Categories and merchants: a name you already have (any case), or one
  /// earlier in the file, is a duplicate. [check] gives the column at fault,
  /// or the row to write.
  static Future<List<PreviewRow>> _names(List<Map<String, String>> rows, Set<String> existing,
      (String?, Map<String, Object?>?) Function(Map<String, String> r) check) async {
    final names = {for (final n in existing) n.toLowerCase()};
    return [
      for (final (i, r) in rows.indexed)
        () {
          final (problem, insert) = check(r);
          if (problem != null) return PreviewRow(row: i + 2, values: r, verdict: CsvVerdict.rejected, problem: problem);
          if (!names.add(r['name']!.toLowerCase())) return PreviewRow(row: i + 2, values: r, verdict: CsvVerdict.duplicate);
          return PreviewRow(row: i + 2, values: r, verdict: CsvVerdict.add, insert: insert);
        }(),
    ];
  }

  static final _color = RegExp(r'^#[0-9a-fA-F]{6}$');

  static (String?, Map<String, Object?>?) _category(Map<String, String> r) {
    final name = r['name']!, type = r['type']!.toLowerCase(), color = r['color'] ?? '';
    if (name.isEmpty) return ('name', null);
    if (!_types.contains(type)) return ('type', null);
    if (color.isNotEmpty && !_color.hasMatch(color)) return ('color', null);
    return (null, {'name': name, 'type': type, 'color': color.isEmpty ? _defaultCategoryColor : color.toLowerCase()});
  }

  static (String?, Map<String, Object?>?) _merchant(Map<String, String> r) =>
      r['name']!.isEmpty ? ('name', null) : (null, {'name': r['name']});

  // ── Import ───────────────────────────────────────────────────────────

  /// Writes the rows [preview] marked to add (transactions as ordinary
  /// entries, not tied to a loan) and the new merchants they name. One
  /// database transaction: open tabs reload once.
  static Future<ImportSummary> importPreview(CsvPreview preview) async {
    final add = [for (final r in preview.rows) if (r.verdict == CsvVerdict.add) r];
    final newMerchants = <String, String>{
      for (final r in add)
        if (r.newMerchant != null) r.newMerchant!.toLowerCase(): r.newMerchant!,
    };
    // The kinds are named after their tables.
    final table = preview.kind.name;
    if (add.isNotEmpty) {
      final store = await LocalStore.instance();
      await store.write((txn) async {
        for (final r in add) {
          await store.insertIn(txn, table, r.insert!);
        }
        for (final name in newMerchants.values) {
          await store.insertIn(txn, 'merchants', {'name': name});
        }
      });
    }
    final transactions = preview.kind == CsvKind.transactions;
    return (
      added: add.length,
      duplicates: preview.count(CsvVerdict.duplicate),
      rejected: preview.count(CsvVerdict.rejected),
      categoriesMatched: transactions ? {for (final r in add) ?r.insert!['category_id']}.length : 0,
      newMerchants: newMerchants.length,
      uncategorized: transactions ? add.where((r) => r.insert!['category_id'] == null).length : 0,
      unknownAccounts: add.where((r) => r.unknownAccount).length,
    );
  }
}
