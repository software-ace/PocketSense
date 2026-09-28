/// Turns a raw speech transcript into the digit-based sentence the voice
/// parser understands: "SPENT TWELVE FIFTY AT SUBWAY" → "spent 12.50 at subway".
///
/// The desktop recognizer spells numbers out and shouts in capitals; Android's
/// recognizer already writes digits, so this only runs on desktop output.
String normalizeSpokenText(String input) {
  final words = input.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  var i = 0;
  while (i < words.length) {
    final n = _cardinal(words, i);
    if (n == null) {
      out.add(words[i++]);
      continue;
    }
    var (value, j) = n;
    var text = '$value';
    if (j < words.length && words[j] == 'point') {
      // "twelve point five" → 12.5
      final digits = StringBuffer();
      var k = j + 1;
      while (k < words.length && _digit(words[k]) != null) {
        digits.write(_digit(words[k++]));
      }
      if (digits.isNotEmpty) (text, j) = ('$value.$digits', k);
    } else if (value < 100 && j < words.length) {
      // How prices are said: "twelve fifty" → 12.50, "nine oh five" → 9.05.
      final oh = words[j] == 'oh' && j + 1 < words.length ? _units[words[j + 1]] : null;
      final cents = _sub100(words, j);
      if (oh != null && oh >= 1 && oh <= 9) {
        (text, j) = ('$value.0$oh', j + 2);
      } else if (cents != null && cents.$1 >= 10) {
        (text, j) = ('$value.${cents.$1}', cents.$2);
      }
    }
    out.add(text);
    i = j;
  }
  return out.join(' ');
}

const _units = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
  'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _tens = {'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90};

int? _digit(String w) => w == 'oh' ? 0 : (_units[w] != null && _units[w]! < 10 ? _units[w] : null);

/// 0–99 starting at [i]: "seven", "fourteen", "forty", "forty two".
(int, int)? _sub100(List<String> w, int i) {
  if (i >= w.length) return null;
  final t = _tens[w[i]];
  if (t != null) {
    final u = i + 1 < w.length ? _units[w[i + 1]] : null;
    return (u != null && u >= 1 && u <= 9) ? (t + u, i + 2) : (t, i + 1);
  }
  final u = _units[w[i]];
  return u == null ? null : (u, i + 1);
}

/// 1–999 starting at [i]: "[a|one…nine] hundred [and] [0–99]" or plain 0–99.
(int, int)? _group(List<String> w, int i) {
  if (i + 1 < w.length && w[i + 1] == 'hundred') {
    final h = w[i] == 'a' ? 1 : _units[w[i]];
    if (h != null && h >= 1 && h <= 9) {
      var j = i + 2;
      if (j + 1 < w.length && w[j] == 'and' && _sub100(w, j + 1) != null) j++;
      final rest = _sub100(w, j);
      return rest == null ? (h * 100, j) : (h * 100 + rest.$1, rest.$2);
    }
  }
  return _sub100(w, i);
}

/// A whole number up to 999,999 starting at [i], e.g. "two thousand five hundred".
(int, int)? _cardinal(List<String> w, int i) {
  final g = (w[i] == 'a' && i + 1 < w.length && w[i + 1] == 'thousand') ? (1, i + 1) : _group(w, i);
  if (g == null) return null;
  var (value, j) = g;
  if (j < w.length && w[j] == 'thousand') {
    value *= 1000;
    j++;
    if (j + 1 < w.length && w[j] == 'and' && _group(w, j + 1) != null) j++;
    final rest = _group(w, j);
    if (rest != null) (value, j) = (value + rest.$1, rest.$2);
  }
  return (value, j);
}
