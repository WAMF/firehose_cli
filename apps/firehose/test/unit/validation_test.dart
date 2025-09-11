import 'dart:io';

import 'package:firehose/src/validation.dart';
import 'package:test/test.dart';

void main() {
  group('JsonValidator', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('firehose_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('loadJsonFile loads valid JSON object', () async {
      final file = File('${tempDir.path}/test.json');
      await file.writeAsString('{"key": "value", "number": 42}');

      final result = await JsonValidator.loadJsonFile(file.path);
      expect(result, isA<Map<String, dynamic>>());
      expect(result['key'], equals('value'));
      expect(result['number'], equals(42));
    });

    test('loadJsonFile loads valid JSON array', () async {
      final file = File('${tempDir.path}/test.json');
      await file.writeAsString('[1, 2, 3]');

      final result = await JsonValidator.loadJsonFile(file.path);
      expect(result, isA<List<dynamic>>());
      expect(result, equals([1, 2, 3]));
    });

    test('loadJsonFile throws for non-existent file', () async {
      expect(
        () => JsonValidator.loadJsonFile('${tempDir.path}/nonexistent.json'),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('File not found')),
        ),
      );
    });

    test('loadJsonFile throws for invalid JSON', () async {
      final file = File('${tempDir.path}/invalid.json');
      await file.writeAsString('{invalid json}');

      expect(
        () => JsonValidator.loadJsonFile(file.path),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('Invalid JSON')),
        ),
      );
    });

    test('validateObject accepts valid object', () {
      final json = {'key': 'value'};
      final result = JsonValidator.validateObject(json, 'test');
      expect(result, equals(json));
    });

    test('validateObject rejects non-object', () {
      expect(
        () => JsonValidator.validateObject([1, 2, 3], 'test'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('must be a JSON object'),
          ),
        ),
      );
    });

    test('validateArray accepts valid array', () {
      final json = [1, 2, 3];
      final result = JsonValidator.validateArray(json, 'test');
      expect(result, equals(json));
    });

    test('validateArray rejects non-array', () {
      expect(
        () => JsonValidator.validateArray({'key': 'value'}, 'test'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('must be a JSON array'),
          ),
        ),
      );
    });

    test('validateArrayOfObjects accepts valid array of objects', () {
      final json = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      final result = JsonValidator.validateArrayOfObjects(json, 'test');
      expect(result, equals(json));
    });

    test('validateArrayOfObjects rejects array with non-object element', () {
      final json = [
        {'id': 1, 'name': 'Alice'},
        'not an object',
        {'id': 3, 'name': 'Charlie'},
      ];
      expect(
        () => JsonValidator.validateArrayOfObjects(json, 'test'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('test[1] must be a JSON object'),
          ),
        ),
      );
    });
  });

  group('PathValidator', () {
    group('validatePath', () {
      test('accepts valid collection path', () {
        final path = PathValidator.validatePath('users');
        expect(path.isCollection, isTrue);
        expect(path.segments, equals(['users']));
        expect(path.collectionId, equals('users'));
      });

      test('accepts valid document path', () {
        final path = PathValidator.validatePath('users/user123');
        expect(path.isDocument, isTrue);
        expect(path.segments, equals(['users', 'user123']));
        expect(path.documentId, equals('user123'));
      });

      test('accepts nested collection path', () {
        final path = PathValidator.validatePath('users/user123/posts');
        expect(path.isCollection, isTrue);
        expect(path.segments, equals(['users', 'user123', 'posts']));
        expect(path.collectionId, equals('posts'));
      });

      test('accepts deeply nested document path', () {
        final path =
            PathValidator.validatePath('users/user123/posts/post456');
        expect(path.isDocument, isTrue);
        expect(path.segments, equals(['users', 'user123', 'posts', 'post456']));
        expect(path.documentId, equals('post456'));
      });

      test('rejects empty path', () {
        expect(
          () => PathValidator.validatePath(''),
          throwsA(
            isA<ValidationException>()
                .having((e) => e.message, 'message', 'Path cannot be empty'),
          ),
        );
      });

      test('rejects path starting with slash', () {
        expect(
          () => PathValidator.validatePath('/users'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot start or end with /'),
            ),
          ),
        );
      });

      test('rejects path ending with slash', () {
        expect(
          () => PathValidator.validatePath('users/'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot start or end with /'),
            ),
          ),
        );
      });

      test('rejects path with empty segment', () {
        expect(
          () => PathValidator.validatePath('users//posts'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('empty segment'),
            ),
          ),
        );
      });

      test('rejects path with . segment', () {
        expect(
          () => PathValidator.validatePath('users/./posts'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot be . or ..'),
            ),
          ),
        );
      });

      test('rejects path with .. segment', () {
        expect(
          () => PathValidator.validatePath('users/../posts'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot be . or ..'),
            ),
          ),
        );
      });

      test('rejects path with reserved segment', () {
        expect(
          () => PathValidator.validatePath('users/__reserved__'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot start and end with __'),
            ),
          ),
        );
      });
    });

    group('validateCollectionPath', () {
      test('accepts valid collection path', () {
        final path = PathValidator.validateCollectionPath('users');
        expect(path.isCollection, isTrue);
      });

      test('rejects document path', () {
        expect(
          () => PathValidator.validateCollectionPath('users/user123'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Expected collection path but got document path'),
            ),
          ),
        );
      });
    });

    group('validateDocumentPath', () {
      test('accepts valid document path', () {
        final path = PathValidator.validateDocumentPath('users/user123');
        expect(path.isDocument, isTrue);
      });

      test('rejects collection path', () {
        expect(
          () => PathValidator.validateDocumentPath('users'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('Expected document path but got collection path'),
            ),
          ),
        );
      });
    });
  });

  group('FirestorePath', () {
    test('parentPath returns correct parent', () {
      final path = PathValidator.validatePath('users/user123/posts/post456');
      expect(path.parentPath, equals('users/user123/posts'));
    });

    test('parentPath returns null for root collection', () {
      final path = PathValidator.validatePath('users');
      expect(path.parentPath, isNull);
    });

    test('documentPath creates document path from collection', () {
      final path = PathValidator.validateCollectionPath('users');
      expect(path.documentPath('user123'), equals('users/user123'));
    });

    test('documentPath throws for document path', () {
      final path = PathValidator.validateDocumentPath('users/user123');
      expect(
        () => path.documentPath('another'),
        throwsA(isA<StateError>()),
      );
    });
  });
}