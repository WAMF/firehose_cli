import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose_cli/src/firestore_client.dart';
import 'package:firehose_cli/src/operation_result.dart';
import 'package:firehose_cli/src/validation.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Command to write a single document from a JSON file
class SingleCommand extends Command<int> {
  /// Creates a new single command instance.
  SingleCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Document path (e.g., users/user123)',
        mandatory: true,
      )
      ..addOption(
        'file',
        abbr: 'f',
        help: 'JSON file path',
        mandatory: true,
      )
      ..addOption(
        'id-field',
        help: 'Field name to use as document ID (optional)',
      )
      ..addFlag(
        'merge',
        help: 'Merge with existing document instead of replacing',
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
  final name = 'single';

  @override
  final description = 'Write one document from a JSON file';

  @override
  Future<int> run() async {
    final path = argResults!['path'] as String;
    final filePath = argResults!['file'] as String;
    final idField = argResults!['id-field'] as String?;
    final merge = argResults!['merge'] as bool;
    final apply = argResults!['apply'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final result = OperationResult();

    try {
      stdout.writeln('Loading JSON from $filePath...');
      final json = await JsonValidator.loadJsonFile(filePath);
      final data = JsonValidator.validateObject(json, 'Root JSON');

      String documentPath;
      final pathValidation = PathValidator.validatePath(path);

      if (pathValidation.isDocument) {
        documentPath = path;
      } else {
        String? docId;
        if (idField != null && data.containsKey(idField)) {
          docId = data[idField]?.toString();
          if (docId == null || docId.isEmpty) {
            throw ValidationException(
              'ID field "$idField" is present but empty or null',
            );
          }
        }

        if (docId == null) {
          throw ValidationException(
            'Path is a collection path but no document ID provided. '
            'Either provide a document path or specify --id-field',
          );
        }

        documentPath = pathValidation.documentPath(docId);
      }

      stdout
        ..writeln('\n=== Operation Plan ===')
        ..writeln('Document: $documentPath')
        ..writeln('Mode: ${merge ? 'Merge' : 'Replace'}')
        ..writeln('Data: ${_summarizeData(data, verbose)}');

      if (!apply) {
        stdout
          ..writeln('\n⚠️  DRY RUN MODE - No changes will be made')
          ..writeln('Use --apply to execute the operation');
        return 0;
      }

      stdout.writeln('\nConnecting to Firestore...');
      final client = await FirestoreClient.fromEnvironment();

      stdout.writeln('Writing document...');
      await _writeDocument(
        client: client,
        path: documentPath,
        data: data,
        merge: merge,
        result: result,
      );

      result.printSummary(verbose: verbose);
      return result.hasErrors ? 1 : 0;
    } on Exception catch (e) {
      stderr.writeln('Error: $e');
      return 2;
    }
  }

  Future<void> _writeDocument({
    required FirestoreClient client,
    required String path,
    required Map<String, dynamic> data,
    required bool merge,
    required OperationResult result,
  }) async {
    try {
      final document = RepositoryFirestoreRestApi.fromJson(
        json: data,
      );

      final fullPath = client.documentPath(path);

      if (merge) {
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
        final segments = path.split('/');
        final docId = segments.last;
        final collectionId = segments[segments.length - 2];
        
        String parentPath;
        if (segments.length > 2) {
          final parentPathSegments = segments.sublist(0, segments.length - 2);
          parentPath = client.documentPath(parentPathSegments.join('/'));
        } else {
          parentPath = '${client.databasePath}/documents';
        }

        await client.firestore.projects.databases.documents.createDocument(
          document,
          parentPath,
          collectionId,
          documentId: docId,
        );
        result.addCreated(path);
      }
    } on Exception catch (e) {
      result.addFailed(path, e.toString());
    }
  }

  String _summarizeData(Map<String, dynamic> data, bool verbose) {
    if (verbose) {
      const encoder = JsonEncoder.withIndent('  ');
      return '\n${encoder.convert(data)}';
    } else {
      return '${data.length} fields';
    }
  }
}
