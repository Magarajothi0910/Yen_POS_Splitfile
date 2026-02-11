import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.

PosColumn createPosColumn({
  required int width,
  required String text,
  PosAlign align = PosAlign.left,
  PosTextSize height = PosTextSize.size1,
  PosTextSize widthSize = PosTextSize.size1,
  String codeTable = 'CP1252',
  required PosStyles styles, // Directly use the passed styles
}) {
  return PosColumn(
    width: width,
    text: text,
    styles: styles, // Use the styles parameter directly
  );
}

PosStyles createPosStyles({
  PosAlign align = PosAlign.left,
  PosTextSize height = PosTextSize.size1,
  PosTextSize width = PosTextSize.size1,
  String codeTable = 'CP1252',
}) {
  return PosStyles(
    align: align,
    height: height,
    width: width,
    codeTable: codeTable,
  );
}
