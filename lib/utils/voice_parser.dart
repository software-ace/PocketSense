import '../models/models.dart';

/// What a spoken sentence says about a transaction. Anything it can't find is
/// left null; the user reviews everything in the form before saving.
class VoiceDraft {
  final int? amountCents;
  final String type; // 'income' | 'expense'
  final String? description;
  final String? merchant;
  final int? categoryId;
  final DateTime date;
  const VoiceDraft({this.amountCents, required this.type, this.description, this.merchant, this.categoryId, required this.date});
}

const _incomeWords = ['earned', 'received', 'got paid', 'income', 'salary', 'paycheck', 'payday', 'refund', 'sold', 'deposit', 'bonus'];
const _weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

// Everyday words → the starter category names. Only used when the user has a
// category with that exact name; their own category names always win.
const _categoryHints = <String, List<String>>{
  'Dining Out': ['coffee', 'lunch', 'dinner', 'breakfast', 'restaurant', 'cafe', 'pizza', 'burger', 'takeout', 'snack'],
  'Groceries': ['grocery', 'groceries', 'supermarket'],
  'Transport': ['uber', 'taxi', 'careem', 'bus', 'fuel', 'gas', 'petrol', 'parking', 'train', 'metro'],
  'Housing': ['rent'],
  'Utilities': ['electricity', 'water bill', 'internet', 'phone bill'],
  'Subscriptions': ['netflix', 'spotify', 'subscription', 'youtube premium'],
  'Entertainment': ['movie', 'cinema', 'concert', 'game'],
  'Health': ['pharmacy', 'doctor', 'medicine', 'dentist', 'gym'],
  'Shopping': ['clothes', 'shoes', 'amazon'],
  'Salary': ['salary', 'paycheck', 'payday'],
  'Freelance': ['freelance', 'client'],
};

// Words that end a "at <merchant>" / "for <thing>" phrase.
final _phraseEnd = RegExp(r'\s+(?:at|from|for|on|in|with|yesterday|today|last|this|\d+\s+days?\s+ago)\b.*$', caseSensitive: false);

/// Parse a sentence like "spent 8.50 on coffee at Blue Bottle yesterday".
VoiceDraft parseVoiceEntry(String input, {required List<Category> categories, DateTime? now}) {
  final at = now ?? DateTime.now();
  var text = ' ${input.trim()} '.replaceAll(RegExp(r'\s+'), ' ');
  final lower = text.toLowerCase();

  // ── Amount: "$8.50", "8.50", "1,200", "12 dollars and 50 cents" ──
  int? cents;
  final money = RegExp(r'\$?\s?(\d{1,3}(?:,\d{3})+|\d+)\b(?!\s*days?\b)(?:\.(\d{1,2}))?(?:\s*(?:dollars?|bucks|usd))?(?:\s+and\s+(\d{1,2})\s+cents?)?', caseSensitive: false)
      .firstMatch(text);
  if (money != null) {
    final whole = int.parse(money.group(1)!.replaceAll(',', ''));
    final frac = money.group(2) ?? money.group(3);
    final fracCents = frac == null ? 0 : int.parse(frac.padRight(2, '0'));
    cents = whole * 100 + fracCents;
    text = text.replaceRange(money.start, money.end, ' ');
  }

  // ── Date ──
  final today = DateTime(at.year, at.month, at.day);
  var date = today;
  final daysAgo = RegExp(r'\b(\d+)\s+days?\s+ago\b', caseSensitive: false).firstMatch(text);
  final weekday = RegExp(r'\b(?:last|on|this past)\s+(' + _weekdays.join('|') + r')\b', caseSensitive: false).firstMatch(text);
  if (RegExp(r'\bday before yesterday\b', caseSensitive: false).hasMatch(text)) {
    date = DateTime(today.year, today.month, today.day - 2);
  } else if (RegExp(r'\byesterday\b', caseSensitive: false).hasMatch(text)) {
    date = DateTime(today.year, today.month, today.day - 1);
  } else if (daysAgo != null) {
    date = DateTime(today.year, today.month, today.day - int.parse(daysAgo.group(1)!));
  } else if (weekday != null) {
    // Most recent past occurrence; "on Monday" said on a Monday means a week ago.
    final target = _weekdays.indexOf(weekday.group(1)!.toLowerCase()) + 1;
    var back = (today.weekday - target) % 7;
    if (back == 0) back = 7;
    date = DateTime(today.year, today.month, today.day - back);
  }
  text = text.replaceAll(
      RegExp(r'\b(?:(?:the\s+)?day before yesterday|yesterday|today|\d+\s+days?\s+ago|(?:last|on|this past)\s+(?:' + _weekdays.join('|') + r'))\b',
          caseSensitive: false),
      ' ');

  // ── Merchant: "at Blue Bottle", or "from Acme" for income ──
  String? merchant;
  final m = RegExp(r'\b(?:at|from)\s+(.+)$', caseSensitive: false).firstMatch(text);
  if (m != null) {
    final rest = m.group(1)!;
    final name = rest.replaceFirst(_phraseEnd, '');
    if (name.trim().isNotEmpty) merchant = _titleCase(name.trim());
    // Remove "at <name>" but keep whatever followed it ("for lunch", ...).
    final keyword = m.group(0)!.length - rest.length;
    text = text.replaceRange(m.start, m.start + keyword + name.length, ' ');
  }

  // ── Category: the user's own names first, then everyday hints ──
  Category? category;
  for (final c in [...categories]..sort((a, b) => b.name.length.compareTo(a.name.length))) {
    if (RegExp(r'\b' + RegExp.escape(c.name.toLowerCase()) + r'\b').hasMatch(lower)) {
      category = c;
      break;
    }
  }
  if (category == null) {
    outer:
    for (final e in _categoryHints.entries) {
      for (final w in e.value) {
        if (RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(lower)) {
          final match = categories.where((c) => c.name.toLowerCase() == e.key.toLowerCase());
          if (match.isNotEmpty) {
            category = match.first;
            break outer;
          }
        }
      }
    }
  }

  // ── Type: income words, or an income category ──
  final income = _incomeWords.any((w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(lower)) || category?.type == 'income';
  final type = income ? 'income' : 'expense';
  if (category != null && category.type != type) category = null;

  // ── Description: "for X" / "on X", else what's left after the rest ──
  String? description;
  final purpose = RegExp(r'\b(?:for|on)\s+(.+)$', caseSensitive: false).firstMatch(text);
  if (purpose != null) {
    final p = purpose.group(1)!.replaceFirst(_phraseEnd, '').trim();
    if (p.isNotEmpty) description = p;
  }
  if (description == null) {
    final leftover = text
        .replaceAll(RegExp(r'\b(?:add|log|record|new|i|i\s+just|just|spent|spend|paid|pay|bought|buy|got|an?|expense|transaction|of|and|dollars?|bucks)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:' + _incomeWords.map(RegExp.escape).join('|') + r')\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[^\w\s&\x27-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (leftover.isNotEmpty) description = leftover;
  }
  if (description != null) description = description[0].toUpperCase() + description.substring(1);

  return VoiceDraft(amountCents: cents, type: type, description: description, merchant: merchant, categoryId: category?.id, date: date);
}

String _titleCase(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
