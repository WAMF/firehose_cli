import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose_cli/src/firestore_client.dart';
import 'package:firehose_cli/src/operation_result.dart';
import 'package:firehose_cli/src/validation.dart';

class DeleteCommand extends Command<int> {
  DeleteCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Document or collection path to delete',
        mandatory: true,
      )
      ..addOption(
        'file',
        abbr: 'f',
        help: 'JSON file with array of document paths to delete (batch mode)',
      )
      ..addFlag(
        'recursive',
        abbr: 'r',
        help: 'Recursively delete all documents in collection',
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
  final name = 'delete';

  @override
  final description = 'Delete documents from Firestore';

  @override
  Future<int> run() async {
    final path = argResults!['path'] as String;
    final filePath = argResults!['file'] as String?;
    final recursive = argResults!['recursive'] as bool;
    final apply = argResults!['apply'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final result = OperationResult();

    try {
      if (filePath != null) {
        return await _batchDelete(
          filePath: filePath,
          basePath: path,
          apply: apply,
          verbose: verbose,
          result: result,
        );
      }

      final pathValidation = PathValidator.validatePath(path);

      if (pathValidation.isDocument) {
        return await _deleteSingleDocument(
          path: path,
          apply: apply,
          verbose: verbose,
          result: result,
        );
      } else {
        if (!recursive) {
          throw ValidationException(
            'Path is a collection. Use --recursive to delete all documents in collection',
          );
        }

        return await _deleteCollection(
          collectionPath: path,
          apply: apply,
          verbose: verbose,
          result: result,
        );
      }
    } on Exception catch (e) {
      stderr.writeln('Error: $e');
      return 2;
    }
  }

  Future<int> _deleteSingleDocument({
    required String path,
    required bool apply,
    required bool verbose,
    required OperationResult result,
  }) async {
    stdout
      ..writeln('\n=== Operation Plan ===')
      ..writeln('Action: Delete document')
      ..writeln('Path: $path');

    if (!apply) {
      stdout
        ..writeln('\n⚠️  DRY RUN MODE - No changes will be made')
        ..writeln('Use --apply to execute the operation');
      return 0;
    }

    stdout.writeln('\nConnecting to Firestore...');
    final client = await FirestoreClient.fromEnvironment();

    stdout.writeln('Deleting document...');
    await _deleteDocument(
      client: client,
      path: path,
      result: result,
    );

    result.printSummary(verbose: verbose);
    return result.hasErrors ? 1 : 0;
  }

  Future<int> _deleteCollection({
    required String collectionPath,
    required bool apply,
    required bool verbose,
    required OperationResult result,
  }) async {
    stdout
      ..writeln('\n=== Operation Plan ===')
      ..writeln('Action: Delete collection (recursive)')
      ..writeln('Collection: $collectionPath');

    if (!apply) {
      stdout
        ..writeln('\n⚠️  DRY RUN MODE - No changes will be made')
        ..writeln('Use --apply to execute the operation');
      return 0;
    }

    stdout.writeln('\nConnecting to Firestore...');
    final client = await FirestoreClient.fromEnvironment();

    stdout.writeln('Fetching documents in collection...');
    final documents = await _listDocuments(client, collectionPath);

    if (documents.isEmpty) {
      stdout.writeln('No documents found in collection');
      return 0;
    }

    stdout.writeln('Deleting ${documents.length} documents...');

    for (var i = 0; i < documents.length; i++) {
      final docPath = documents[i];
      await _deleteDocument(
        client: client,
        path: docPath,
        result: result,
      );

      if ((i + 1) % 10 == 0 || i == documents.length - 1) {
        stdout.write('\rProgress: ${i + 1}/${documents.length}');
      }
    }

    stdout.writeln();
    result.printSummary(verbose: verbose);
    return result.hasErrors ? 1 : 0;
  }

  Future<int> _batchDelete({
    required String filePath,
    required String basePath,
    required bool apply,
    required bool verbose,
    required OperationResult result,
  }) async {
    stdout.writeln('Loading paths from $filePath...');
    final json = await JsonValidator.loadJsonFile(filePath);
    final array = JsonValidator.validateArray(json, 'Root JSON');
    final paths = <String>[];

    for (final item in array) {
      if (item is! String) {
        throw ValidationException(
          'File must contain an array of document path strings',
        );
      }
      paths.add(item);
    }

    stdout
      ..writeln('\n=== Operation Plan ===')
      ..writeln('Action: Batch delete')
      ..writeln('Documents: ${paths.length}');

    if (verbose) {
      stdout.writeln('\nPaths to delete:');
      for (var i = 0; i < (paths.length < 10 ? paths.length : 10); i++) {
        stdout.writeln('  [${i + 1}] ${paths[i]}');
      }
      if (paths.length > 10) {
        stdout.writeln('  ... and ${paths.length - 10} more');
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

    stdout.writeln('Deleting ${paths.length} documents...');

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      await _deleteDocument(
        client: client,
        path: path,
        result: result,
      );

      if ((i + 1) % 10 == 0 || i == paths.length - 1) {
        stdout.write('\rProgress: ${i + 1}/${paths.length}');
      }
    }

    stdout.writeln();
    result.printSummary(verbose: verbose);
    return result.hasErrors ? 1 : 0;
  }

  Future<void> _deleteDocument({
    required FirestoreClient client,
    required String path,
    required OperationResult result,
  }) async {
    try {
      final fullPath = client.documentPath(path);
      await client.firestore.projects.databases.documents.delete(fullPath);
      result.addDeleted(path);
    } on Exception catch (e) {
      result.addFailed(path, e.toString());
    }
  }

  Future<List<String>> _listDocuments(
    FirestoreClient client,
    String collectionPath,
  ) async {
    final paths = <String>[];
    final collection = PathValidator.validateCollectionPath(collectionPath);

    final parentPath = collection.parentPath ?? '';
    final basePath = parentPath.isEmpty
        ? '${client.databasePath}/documents'
        : client.documentPath(parentPath);

    String? pageToken;
    do {
      final response = await client.firestore.projects.databases.documents.list(
        basePath,
        collection.collectionId!,
        pageToken: pageToken,
        pageSize: 100,
      );

      if (response.documents != null) {
        for (final doc in response.documents!) {
          if (doc.name != null) {
            final relativePath = _extractRelativePath(
              doc.name!,
              client.databasePath,
            );
            paths.add(relativePath);
          }
        }
      }

      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return paths;
  }

  String _extractRelativePath(String fullPath, String databasePath) {
    final prefix = '$databasePath/documents/';
    if (fullPath.startsWith(prefix)) {
      return fullPath.substring(prefix.length);
    }
    return fullPath;
  }
}
