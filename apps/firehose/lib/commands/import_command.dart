import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose/src/firestore_client.dart';
import 'package:firehose/src/operation_result.dart';
import 'package:firehose/src/validation.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Command for multi-collection import from a JSON map
class ImportCommand extends Command<int> {
  /// Creates a new import command instance.
  ImportCommand() {
    argParser
      ..addOption(
        'file',
        abbr: 'f',
        help: 'JSON file path with collection map structure',
        mandatory: true,
      )
      ..addFlag(
        'merge',
        help: 'Merge with existing documents instead of replacing',
      )
      ..addFlag(
        'apply',
        help: 'Apply changes (without this flag, runs in dry-run mode)',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output',
      );
  }
  @override
  final name = 'import';

  @override
  final description = 'Multi-collection import from a JSON map file';

  @override
  Future<int> run() async {
    final filePath = argResults!['file'] as String;
    final merge = argResults!['merge'] as bool;
    final apply = argResults!['apply'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final result = OperationResult();

    try {
      stdout.writeln('Loading JSON from $filePath...');
      final json = await JsonValidator.loadJsonFile(filePath);
      final collectionMap = JsonValidator.validateObject(json, 'Root JSON');

      final importPlan = _validateImportStructure(collectionMap);

      stdout
        ..writeln('\n=== Import Plan ===')
        ..writeln('Collections: ${importPlan.length}')
        ..writeln('Mode: ${merge ? 'Merge' : 'Replace'}');

      var totalDocs = 0;
      for (final collection in importPlan) {
        stdout.writeln(
          '  ${collection.path}: ${collection.documents.length} documents'
          '${collection.idFieldName != null ? ' (ID field: ${collection.idFieldName})' : ''}',
        );
        totalDocs += collection.documents.length;
      }
      stdout.writeln('Total documents: $totalDocs');

      if (!apply) {
        stdout
          ..writeln('\n⚠️  DRY RUN MODE - No changes will be made')
          ..writeln('Use --apply to execute the operation');
        return 0;
      }

      stdout.writeln('\nConnecting to Firestore...');
      final client = await FirestoreClient.fromEnvironment();

      stdout.writeln(
        'Importing $totalDocs documents across ${importPlan.length} collections...',
      );

      for (final collection in importPlan) {
        stdout.writeln('\nCollection: ${collection.path}');

        for (var i = 0; i < collection.documents.length; i++) {
          final doc = collection.documents[i];
          String? docId;

          if (collection.idFieldName != null &&
              doc.containsKey(collection.idFieldName)) {
            docId = doc[collection.idFieldName]?.toString();
          }

          await _writeDocument(
            client: client,
            collectionPath: collection.firestorePath,
            documentId: docId,
            data: doc,
            merge: merge,
            result: result,
            index: i,
          );

          if ((i + 1) % 10 == 0 || i == collection.documents.length - 1) {
            stdout.write(
              '\r  Progress: ${i + 1}/${collection.documents.length}',
            );
          }
        }
        stdout.writeln();
      }

      result.printSummary(verbose: verbose);
      return result.hasErrors ? 1 : 0;
    } on Exception catch (e) {
      stderr.writeln('Error: $e');
      return 2;
    }
  }

  List<CollectionImport> _validateImportStructure(
    Map<String, dynamic> collectionMap,
  ) {
    final imports = <CollectionImport>[];

    for (final entry in collectionMap.entries) {
      final collectionPath = entry.key;
      final collectionData = entry.value;

      if (collectionData is! Map<String, dynamic>) {
        throw ValidationException(
          'Collection "$collectionPath" must be an object with "data" array',
        );
      }

      if (!collectionData.containsKey('data')) {
        throw ValidationException(
          'Collection "$collectionPath" must have a "data" field',
        );
      }

      final data = collectionData['data'];
      if (data is! List) {
        throw ValidationException(
          'Collection "$collectionPath" data field must be an array',
        );
      }

      final documents = JsonValidator.validateArrayOfObjects(
        data,
        'Collection "$collectionPath" documents',
      );

      final idFieldName = collectionData['id field name'] as String?;
      final firestorePath = PathValidator.validateCollectionPath(
        collectionPath,
      );

      imports.add(
        CollectionImport(
          path: collectionPath,
          firestorePath: firestorePath,
          idFieldName: idFieldName,
          documents: documents,
        ),
      );
    }

    return imports;
  }

  Future<void> _writeDocument({
    required FirestoreClient client,
    required FirestorePath collectionPath,
    required String? documentId,
    required Map<String, dynamic> data,
    required bool merge,
    required OperationResult result,
    required int index,
  }) async {
    final isAutoId = documentId == null || documentId.isEmpty;
    final effectiveId =
        isAutoId
            ? 'auto_${DateTime.now().millisecondsSinceEpoch}_$index'
            : documentId;

    final path = collectionPath.documentPath(effectiveId);

    try {
      final document = RepositoryFirestoreRestApi.fromJson(
        json: data,
      );

      final fullPath = client.documentPath(path);

      if (merge && !isAutoId) {
        final request = Document(
          name: fullPath,
          fields: document.fields,
        );

        await client.firestore.projects.databases.documents.patch(
          request,
          fullPath,
          updateMask_fieldPaths: document.fields?.keys.toList(),
        );
        result.addUpdated(path);
      } else {
        final parentPath =
            collectionPath.segments.length > 1
                ? client.documentPath(collectionPath.parentPath!)
                : '${client.databasePath}/documents';

        await client.firestore.projects.databases.documents.createDocument(
          document,
          parentPath,
          collectionPath.collectionId!,
          documentId: isAutoId ? null : effectiveId,
        );
        result.addCreated(path, autoId: isAutoId);
      }
    } on Exception catch (e) {
      result.addFailed(path, e.toString());
    }
  }
}

/// Represents a collection to be imported.
class CollectionImport {
  /// Creates a collection import.
  CollectionImport({
    required this.path,
    required this.firestorePath,
    required this.idFieldName,
    required this.documents,
  });

  /// The collection path.
  final String path;

  /// The validated Firestore path.
  final FirestorePath firestorePath;

  /// The field name to use as document ID.
  final String? idFieldName;

  /// The documents to import.
  final List<Map<String, dynamic>> documents;
}
