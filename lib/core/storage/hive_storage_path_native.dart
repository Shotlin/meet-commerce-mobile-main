import 'package:path_provider/path_provider.dart';

Future<String?> resolveHiveStoragePath() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}
