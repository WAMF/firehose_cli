import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose/src/firestore_client.dart';
import 'package:firehose/src/operation_result.dart';
import 'package:firehose/src/validation.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Command to write many documents to a collection from a JSON array file
class BatchCommand extends Command<int> {
  /// Creates a new batch command instance.
  BatchCommand() {
    argParser
      ..addOption(
        'collection',
        abbr: 'c',
        help: 'Collection path (e.g., users)',
        mandatory: true,
      )
      ..addOption(
        'file',
        abbr: 'f',
        help: 'JSON file path containing an array of documents',
        mandatory: true,
      )
      ..addOption(
        'id-field',
        help: 'Field name to use as document ID (auto-ID if not found)',
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
  final name = 'batch';

  @override
  final description =
      'Write many documents to one collection from a JSON array file';

  @override
  Future<int> run() async {
    final collectionPath = argResults!['collection'] as String;
    final filePath = argResults!['file'] as String;
    final idField = argResults!['id-field'] as String?;
    final merge = argResults!['merge'] as bool;
    final apply = argResults!['apply'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final result = OperationResult();

    try {
      stdout.writeln('Loading JSON from $filePath...');
      final json = await JsonValidator.loadJsonFile(filePath);
      final array = JsonValidator.validateArray(json, 'Root JSON');
      final documents = JsonValidator.validateArrayOfObjects(
        array,
        'Documents',
      );

      final collection = PathValidator.validateCollectionPath(collectionPath);

      stdout
        ..writeln('\n=== Operation Plan ===')
        ..writeln('Collection: $collectionPath')
        ..writeln('Documents: ${documents.length}')
        ..writeln('Mode: ${merge ? 'Merge' : 'Replace'}');

      final preview = _analyzeDocuments(documents, idField);
      stdout.writeln(
        'ID Strategy: ${preview.withId} with ID field, ${preview.autoId} auto-ID',
      );

      if (verbose) {
        stdout.writeln('\nDocument preview:');
        for (
          var i = 0;
          i < (documents.length < 5 ? documents.length : 5);
          i++
        ) {
          final doc = documents[i];
          final docId = idField != null ? doc[idField]?.toString() : null;
          stdout.writeln(
            '  [${i + 1}] ${docId ?? '(auto-ID)'}: ${doc.length} fields',
          );
        }
        if (documents.length > 5) {
          stdout.writeln('  ... and ${documents.length - 5} more');
        }
      }

      if (!apply) {
        stdout
          ..writeln('\n⚠️  DRY RUN MODE - No changes will be made')
          ..writeln('Use --apply to execute the operation');
        return 0;
      }

      stdout.writeln('\nConnecting to Firestore...');
      final client = await FirestoreClient.fromEnvironment();

      stdout.writeln('Writing ${documents.length} documents...');

      for (var i = 0; i < documents.length; i++) {
        final doc = documents[i];
        String? docId;

        if (idField != null && doc.containsKey(idField)) {
          docId = doc[idField]?.toString();
        }

        await _writeDocument(
          client: client,
          collection: collection,
          documentId: docId,
          data: doc,
          merge: merge,
          result: result,
          index: i,
        );

        if ((i + 1) % 10 == 0 || i == documents.length - 1) {
          stdout.write('\rProgress: ${i + 1}/${documents.length}');
        }
      }

      stdout.writeln();
      result.printSummary(verbose: verbose);
      return result.hasErrors ? 1 : 0;
    } on Exception catch (e) {
      stderr.writeln('Error: $e');
      return 2;
    }
  }

  Future<void> _writeDocument({
    required FirestoreClient client,
    required FirestorePath collection,
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

    final path = collection.documentPath(effectiveId);

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
            collection.segments.length > 1
                ? client.documentPath(collection.parentPath!)
                : '${client.databasePath}/documents';

        await client.firestore.projects.databases.documents.createDocument(
          document,
          parentPath,
          collection.collectionId!,
          documentId: isAutoId ? null : effectiveId,
        );
        result.addCreated(path, autoId: isAutoId);
      }
    } on Exception catch (e) {
      result.addFailed(path, e.toString());
    }
  }

  DocumentPreview _analyzeDocuments(
    List<Map<String, dynamic>> documents,
    String? idField,
  ) {
    var withId = 0;
    var autoId = 0;

    for (final doc in documents) {
      if (idField != null &&
          doc.containsKey(idField) &&
          doc[idField] != null &&
          doc[idField].toString().isNotEmpty) {
        withId++;
      } else {
        autoId++;
      }
    }

    return DocumentPreview(withId: withId, autoId: autoId);
  }
}

/// Preview of documents to be imported.
class DocumentPreview {
  /// Creates a document preview.
  DocumentPreview({required this.withId, required this.autoId});

  /// Number of documents with ID field.
  final int withId;

  /// Number of documents requiring auto-generated IDs.
  final int autoId;
}
