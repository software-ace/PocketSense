// CSV as RFC 4180 writes it: comma-separated, every field quoted with
// quotes doubled inside, CRLF between rows.

/// Writes [rows] as CSV, starting with a byte order mark: without it, Excel
/// reads UTF-8 as the system code page and garbles Arabic. Every field is
/// quoted, even "Abdali Mall": a spreadsheet set to split on spaces too
/// (LibreOffice remembers that choice) never splits inside quotes.
String encodeCsv(List<List<Object?>> rows) {
  String field(Object? v) => '"${(v?.toString() ?? '').replaceAll('"', '""')}"';

  return '﻿${rows.map((r) => r.map(field).join(',')).join('\r\n')}\r\n';
}

/// Reads CSV into rows of fields, skipping blank lines. Accepts LF or CRLF,
/// and a byte order mark. An unclosed quote at a field's start takes the
/// rest of the file.
List<List<String>> decodeCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var i = text.startsWith('﻿') ? 1 : 0;

  void endRow() {
    row.add(field.toString());
    field.clear();
    if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
    row = <String>[];
  }

  for (; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c != '"') {
        field.write(c);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (c == '"' && field.isEmpty) {
      // Only at a field's start; elsewhere (15" monitor) it's a plain character.
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
