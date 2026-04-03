import 'dart:io';

void main() {
  final dir = Directory('lib');
  final entities = dir.listSync(recursive: true);
  
  for (var entity in entities) {
    if (entity is File && entity.path.endsWith('.dart')) {
      var content = entity.readAsStringSync();

      content = content.replaceAll('Brightness.dark', 'Brightness.light');
      content = content.replaceAll('0xFF121212', '0xFFFFFFFF');
      content = content.replaceAll('0xFF363636', '0xFFF5F5F5');
      content = content.replaceAll('0xFF1D1D1D', '0xFFF5F5F5');
      content = content.replaceAll('Colors.grey[800]', 'Colors.grey[300]');
      content = content.replaceAll('Colors.grey[900]', 'Colors.grey[200]');

      // Replace colors
      content = content.replaceAll('Colors.white54', 'Colors.black54');
      content = content.replaceAll('Colors.white70', 'Colors.black87');
      content = content.replaceAll('Colors.white24', 'Colors.black26');
      content = content.replaceAll('Colors.white10', 'Colors.black12');
      content = content.replaceAll('Colors.white', 'Colors.black87');
      
      // Specifically fix buttons that might be hardcoded to black87 now
      content = content.replaceAll('color: Colors.black87,', 'color: Colors.black87,');

      entity.writeAsStringSync(content);
    }
  }
  print('Done');
}
