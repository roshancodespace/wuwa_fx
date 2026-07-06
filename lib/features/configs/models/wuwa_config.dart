import 'dart:io';
import 'package:path/path.dart' as path;

class WuwaConfig {
  final String id;
  final String name;
  final String category;
  final String relativePath;
  final String absolutePath;
  final List<String> iniFiles;
  final bool isExperimental;
  final String? parentName;

  const WuwaConfig({
    required this.id,
    required this.name,
    required this.category,
    required this.relativePath,
    required this.absolutePath,
    required this.iniFiles,
    required this.isExperimental,
    this.parentName,
  });

  /// Reads the content of all .ini files in this configuration directory.
  /// Returns a map of filename -> content (e.g. {'Engine.ini': '[Core.System]...'}).
  Future<Map<String, String>> readIniContents() async {
    final Map<String, String> contents = {};
    for (final fileName in iniFiles) {
      final file = File(path.join(absolutePath, fileName));
      if (await file.exists()) {
        try {
          contents[fileName] = await file.readAsString();
        } catch (e) {
          contents[fileName] = 'Error reading file: $e';
        }
      } else {
        contents[fileName] = 'File not found on disk.';
      }
    }
    return contents;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'relativePath': relativePath,
      'absolutePath': absolutePath,
      'iniFiles': iniFiles,
      'isExperimental': isExperimental,
      'parentName': parentName,
    };
  }

  factory WuwaConfig.fromJson(Map<String, dynamic> json) {
    return WuwaConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      relativePath: json['relativePath'] as String,
      absolutePath: json['absolutePath'] as String,
      iniFiles: List<String>.from(json['iniFiles'] ?? []),
      isExperimental: json['isExperimental'] as bool? ?? false,
      parentName: json['parentName'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WuwaConfig && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
