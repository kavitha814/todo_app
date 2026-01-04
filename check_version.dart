import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('.dart_tool/package_config.json');
  if (!file.existsSync()) {
    print('No package_config.json');
    return;
  }
  final content = await file.readAsString();
  final json = jsonDecode(content);
  final packages = json['packages'] as List;
  final fln = packages.firstWhere(
    (p) => p['name'] == 'flutter_local_notifications',
    orElse: () => null,
  );
  if (fln != null) {
    print('flutter_local_notifications: ${fln['rootUri']}');
  } else {
    print('flutter_local_notifications not found');
  }
}
