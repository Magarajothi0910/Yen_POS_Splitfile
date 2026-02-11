import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final Dio dio = Dio();

Future<void> fetchAndStoreLogo() async {
  final box = Hive.box('logo');
  const String logoUrl =
      "https://yenerp.com/bmecommerceapi/weblogos/logo/view/Logo";
  const String logoFileName = "BMlogo.png";

  try {
    final response = await dio.get<List<int>>(
      logoUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200 && response.data != null) {
      final Uint8List bytes = Uint8List.fromList(response.data!);

      // 📁 Save file locally (optional but useful for debugging or reuse)
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String filePath = "${appDir.path}/$logoFileName";
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      // 💾 Store in Hive
      await box.put('BMlogo_bytes', bytes);
      await box.put('BMlogo_name', logoFileName);
      await box.put('BMlogo_path', filePath);
      await box.put('BMlogo_lastFetched', DateTime.now().toIso8601String());

    } else {
    }
  } catch (e) {
  }
}
