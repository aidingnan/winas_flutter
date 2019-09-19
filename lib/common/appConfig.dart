import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppConfig {
  static bool isDev = false;

  static bool umeng = true;

  /// cloud address
  static String get cloudAddress => AppConfig.isDev
      ? 'https://test.aidingnan.com/c/v1'
      : 'https://aws-cn.aidingnan.com/c/v1';

  /// check if `ApplicationDocumentsDirectory/dev` exists
  static Future<bool> checkDev() async {
    Directory root = await getApplicationDocumentsDirectory();
    File devFile = File("${root.path}/dev");
    bool devFileExists = await devFile.exists();
    AppConfig.isDev = devFileExists == true;
    return devFileExists == true;
  }

  /// delete or create `ApplicationDocumentsDirectory/dev`
  static Future<void> toggleDev() async {
    Directory root = await getApplicationDocumentsDirectory();
    File devFile = File("${root.path}/dev");
    bool devFileExists = await devFile.exists();
    if (devFileExists == true) {
      await devFile.delete();
      AppConfig.isDev = false;
    } else {
      await devFile.create();
      AppConfig.isDev = true;
    }
  }
}
