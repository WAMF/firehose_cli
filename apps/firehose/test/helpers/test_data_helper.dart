import 'dart:convert';
import 'dart:io';

class TestDataHelper {
  static Future<File> createTempJsonFile(
    String content, {
    String? fileName,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('firehose_test_');
    final file = File('${tempDir.path}/${fileName ?? 'test.json'}');
    await file.writeAsString(content);
    return file;
  }

  static Future<File> createJsonObjectFile(Map<String, dynamic> data) async {
    return createTempJsonFile(jsonEncode(data));
  }

  static Future<File> createJsonArrayFile(List<dynamic> data) async {
    return createTempJsonFile(jsonEncode(data));
  }

  static Map<String, dynamic> createTestDocument({
    String? id,
    String? name,
    int? age,
    Map<String, dynamic>? additionalFields,
  }) {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      ...?additionalFields,
    };
  }

  static List<Map<String, dynamic>> createTestDocuments(int count) {
    return List.generate(
      count,
      (i) => createTestDocument(
        id: 'doc$i',
        name: 'Test User $i',
        age: 20 + i,
        additionalFields: {
          'email': 'user$i@example.com',
          'active': i % 2 == 0,
        },
      ),
    );
  }

  static Map<String, dynamic> createImportData({
    required Map<String, List<Map<String, dynamic>>> collections,
    String idField = 'id',
  }) {
    final result = <String, dynamic>{};
    
    for (final entry in collections.entries) {
      result[entry.key] = {
        'id field name': idField,
        'data': entry.value,
      };
    }
    
    return result;
  }

  static Future<void> cleanupTempFiles(File file) async {
    try {
      final parent = file.parent;
      if (parent.path.contains('firehose_test_')) {
        await parent.delete(recursive: true);
      } else {
        await file.delete();
      }
    } catch (_) {
    }
  }
}