import 'dart:io';

void main() {
  final dir = Directory('lib');
  final entities = dir.listSync(recursive: true);
  
  for (var entity in entities) {
    if (entity is File && entity.path.endsWith('.dart')) {
      var content = entity.readAsStringSync();

      content = content.replaceAll('Colors.black8738', 'Colors.black38');
      content = content.replaceAll('Colors.black8712', 'Colors.black12');

      entity.writeAsStringSync(content);
    }
  }
  print('Done');
}
