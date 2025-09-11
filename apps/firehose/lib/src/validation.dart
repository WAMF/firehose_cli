import 'dart:convert';
import 'dart:io';

/// Validates and loads JSON from a file
class JsonValidator {
  /// Maximum file size in bytes (100MB).
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  /// Loads and validates a JSON file, returning the parsed object
  static Future<dynamic> loadJsonFile(String filePath) async {
    final file = File(filePath);

    if (!file.existsSync()) {
      throw ValidationException('File not found: $filePath');
    }

    final stat = file.statSync();
    if (stat.size > maxFileSizeBytes) {
      throw ValidationException(
        'File size exceeds limit (${stat.size} bytes > $maxFileSizeBytes bytes)',
      );
    }

    final content = await file.readAsString();

    try {
      return jsonDecode(content);
    } catch (e) {
      throw ValidationException('Invalid JSON in file $filePath: $e');
    }
  }

  /// Validates that the JSON is an object (Map)
  static Map<String, dynamic> validateObject(
    dynamic json,
    String context,
  ) {
    if (json is! Map<String, dynamic>) {
      throw ValidationException(
        '$context must be a JSON object, got ${json.runtimeType}',
      );
    }
    return json;
  }

  /// Validates that the JSON is an array (List)
  static List<dynamic> validateArray(
    dynamic json,
    String context,
  ) {
    if (json is! List<dynamic>) {
      throw ValidationException(
        '$context must be a JSON array, got ${json.runtimeType}',
      );
    }
    return json;
  }

  /// Validates that each item in the list is an object
  static List<Map<String, dynamic>> validateArrayOfObjects(
    List<dynamic> array,
    String context,
  ) {
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < array.length; i++) {
      if (array[i] is! Map<String, dynamic>) {
        throw ValidationException(
          '$context[$i] must be a JSON object, got ${array[i].runtimeType}',
        );
      }
      result.add(array[i] as Map<String, dynamic>);
    }
    return result;
  }
}

/// Validates Firestore paths
class PathValidator {
  /// Maximum number of path segments.
  static const int maxPathSegments = 100;

  /// Maximum length of a document ID.
  static const int maxIdLength = 1500;

  /// Validates a Firestore path (collection or document)
  static FirestorePath validatePath(String path) {
    if (path.isEmpty) {
      throw ValidationException('Path cannot be empty');
    }

    if (path.startsWith('/') || path.endsWith('/')) {
      throw ValidationException('Path cannot start or end with /');
    }

    final segments = path.split('/');

    if (segments.length > maxPathSegments) {
      throw ValidationException(
        'Path has too many segments (${segments.length} > $maxPathSegments)',
      );
    }

    for (final segment in segments) {
      if (segment.isEmpty) {
        throw ValidationException('Path contains empty segment');
      }
      if (segment.length > maxIdLength) {
        throw ValidationException(
          'Path segment exceeds max length (${segment.length} > $maxIdLength)',
        );
      }
      if (segment == '.' || segment == '..') {
        throw ValidationException('Path segment cannot be . or ..');
      }
      if (segment.startsWith('__') && segment.endsWith('__')) {
        throw ValidationException(
          'Path segment cannot start and end with __ (reserved)',
        );
      }
    }

    final isCollection = segments.length.isOdd;
    return FirestorePath(
      path: path,
      segments: segments,
      isCollection: isCollection,
    );
  }

  /// Validates a collection path specifically
  static FirestorePath validateCollectionPath(String path) {
    final firestorePath = validatePath(path);
    if (!firestorePath.isCollection) {
      throw ValidationException(
        'Expected collection path but got document path: $path',
      );
    }
    return firestorePath;
  }

  /// Validates a document path specifically
  static FirestorePath validateDocumentPath(String path) {
    final firestorePath = validatePath(path);
    if (firestorePath.isCollection) {
      throw ValidationException(
        'Expected document path but got collection path: $path',
      );
    }
    return firestorePath;
  }
}

/// Represents a validated Firestore path
class FirestorePath {
  /// Creates a Firestore path.
  FirestorePath({
    required this.path,
    required this.segments,
    required this.isCollection,
  });

  /// The original path string.
  final String path;

  /// The path segments.
  final List<String> segments;

  /// Whether this is a collection path.
  final bool isCollection;

  /// Whether this is a document path.
  bool get isDocument => !isCollection;

  /// Gets the collection ID if this is a collection path.
  String? get collectionId => isCollection ? segments.last : null;

  /// Gets the document ID if this is a document path.
  String? get documentId => isDocument ? segments.last : null;

  /// Gets the parent path.
  String? get parentPath {
    if (segments.length <= 1) return null;
    return segments.sublist(0, segments.length - 1).join('/');
  }

  /// Creates a document path from this collection path.
  String documentPath(String documentId) {
    if (!isCollection) {
      throw StateError('Cannot create document path from document path');
    }
    return '$path/$documentId';
  }
}

/// Custom exception for validation errors
class ValidationException implements Exception {
  /// Creates a validation exception.
  ValidationException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}
