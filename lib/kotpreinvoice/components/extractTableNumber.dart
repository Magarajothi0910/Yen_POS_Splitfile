String extractMainTable(String table) {
  // Removes any trailing letters like B, C from "Table 3B"
  final regex = RegExp(r'^Table\s+\d+');
  final match = regex.firstMatch(table);
  return match?.group(0) ?? table;
}
