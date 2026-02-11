import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

PosColumn createPosColumn({
  required int width,
  String? text,
  PosStyles? styles,
}) {
  return PosColumn(
    width: width,
    text: text ?? '',
    styles: styles ?? PosStyles(),
  );
}

PosStyles createPosStyles({
  PosAlign align = PosAlign.left,
  PosTextSize height = PosTextSize.size1,
  PosTextSize width = PosTextSize.size1,
  String codeTable = 'CP1252',
  bool? bold,
}) {
  return PosStyles(
    align: align,
    height: height,
    width: width,
    codeTable: codeTable,
  );
}

// ----------------- Helper: Strike-through text image -----------------
Future<img.Image> textWithStrikeImage({
  required String snoText,
  required String itemName,
  required String amountText,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final textStyle = TextStyle(
    color: const ui.Color(0xFF000000),
    fontSize: 24,
  );

  // -------- Paint Left Text (Item details) --------
  final textPainter1 = TextPainter(
    text: TextSpan(text: "$snoText$itemName", style: textStyle),
    textDirection: ui.TextDirection.ltr,
    maxLines: 2, // allow wrapping if long
    ellipsis: "...",
  );
  textPainter1.layout(maxWidth: 400); // restrict left text width

  // -------- Paint Right Text (Amount) --------
  final textPainter2 = TextPainter(
    text: TextSpan(text: amountText, style: textStyle),
    textDirection: ui.TextDirection.ltr,
  );
  textPainter2.layout();

  // -------- Fixed paper width (80mm ~ 550–570 px) --------
  const fixedWidth = 560.0;

  // Left starts at 0
  final itemOffset = 0.0;

  // Amount always right aligned
  final amountOffsetX = fixedWidth - textPainter2.width;

  // Height = max of both
  final totalHeight = (textPainter1.height > textPainter2.height
          ? textPainter1.height
          : textPainter2.height)
      .ceil();

  // Paint left text
  textPainter1.paint(canvas, ui.Offset(itemOffset, 0));

  // Paint right amount
  textPainter2.paint(canvas, ui.Offset(amountOffsetX, 0));

  // Strike-through on amount
  final linePaint = ui.Paint()
    ..color = const ui.Color(0xFF000000)
    ..strokeWidth = 2;
  final lineY = textPainter2.height / 2;
  canvas.drawLine(
    ui.Offset(amountOffsetX, lineY),
    ui.Offset(amountOffsetX + textPainter2.width, lineY),
    linePaint,
  );

  // End recording
  final picture = recorder.endRecording();
  final imgUi = await picture.toImage(fixedWidth.ceil(), totalHeight);

  // Convert to PNG
  final byteData = await imgUi.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  // Convert to image.Image (esc_pos_utils needs this)
  final imageObj = img.decodePng(pngBytes)!;

  // White background fill
  final background = img.Image(imageObj.width, imageObj.height);
  img.fill(background, img.getColor(255, 255, 255));
  img.copyInto(background, imageObj);

  return background;
}

// Convert image asset to esc_pos_utils Image
