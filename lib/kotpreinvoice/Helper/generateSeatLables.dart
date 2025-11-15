String generateSeatLabel(int index) {
  const letters = 26;
  int round = index ~/ letters;
  int letterIndex = index % letters;

  String letter = String.fromCharCode(65 + letterIndex); // A-Z

  if (round == 0) return letter; // A-Z
  return '$letter$round'; // A1-Z1, A2-Z2, ...
}
