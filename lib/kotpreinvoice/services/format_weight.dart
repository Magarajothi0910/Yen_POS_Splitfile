String formatWeight(dynamic weight) {
  if (weight == null) return '';

  final double w = weight.toDouble();
  if (w <= 0) return '';

  if (w < 1) {
    // convert kg → grams
    return '${(w * 1000).toStringAsFixed(0)}g';
  } else {
    // keep in kg
    return '${w.toStringAsFixed(3)}kg';
  }
}
