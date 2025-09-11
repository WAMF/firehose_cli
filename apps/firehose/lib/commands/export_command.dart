import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose/src/firestore_client.dart';
import 'package:firehose/src/operation_result.dart';
import 'package:firehose/src/validation.dart';
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Command to export Firestore data to JSON
class ExportCommand extends Command<int> {
  /// Creates a new export command instance.
  ExportCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Collection or document path to export',
        mandatory: true,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output JSON file path (omit to write to stdout)',
      )
      ..addOption(
        'limit',
        help: 'Maximum number of documents to export (collection only)',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output',
      );
  }
  @override
  final name = 'export';

  @override
  final description = 'Export Firestore data to JSON file';

  @override
  Future<int> run() async {
    final path = argResults!['path'] as String;
    final outputPath = argResults!['output'] as String?;
    final limitStr = argResults!['limit'] as String?;
    final verbose = argResults!['verbose'] as bool;

    final limit = limitStr != null ? int.tryParse(limitStr) : null;
    if (limitStr != null && limit == null) {
      stderr.writeln('Error: Invalid limit value: $limitStr');
      return 2;
    }

    final result = OperationResult();
    final outputToStdout = outputPath == null;

    try {
      final firestorePath = PathValidator.validatePath(path);

      if (!outputToStdout) {
        stdout.writeln('Connecting to Firestore...');
      }
      final client = await FirestoreClient.fromEnvironment();

      if (!outputToStdout) {
        stdout.writeln(
          'Exporting ${firestorePath.isCollection ? 'collection' : 'document'}: $path',
        );
      }

      dynamic exportData;

      if (firestorePath.isCollection) {
        exportData = await _exportCollection(
          client: client,
          collectionPath: firestorePath,
          limit: limit,
          result: result,
          verbose: verbose && !outputToStdout,
          outputToStdout: outputToStdout,
        );
      } else {
        exportData = await _exportDocument(
          client: client,
          documentPath: firestorePath,
          result: result,
        );
      }

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(exportData);
      
      if (outputToStdout) {
        stdout.write(jsonString);
        if (!jsonString.endsWith('\n')) {
          stdout.writeln();
        }
      } else {
        stdout.writeln('Writing to $outputPath...');
        final file = File(outputPath);
        await file.writeAsString(jsonString);
        result
          ..bytesWritten = jsonString.length
          ..printSummary(verbose: verbose);
      }
      
      return result.hasErrors ? 1 : 0;
    } on Exception catch (e) {
      stderr.writeln('Error: $e');
      return 2;
    }
  }

  Future<Map<String, dynamic>> _exportCollection({
    required FirestoreClient client,
    required FirestorePath collectionPath,
    required int? limit,
    required OperationResult result,
    required bool verbose,
    bool outputToStdout = false,
  }) async {
    final documents = <Map<String, dynamic>>[];

    try {
      final parentPath = collectionPath.parentPath ?? '';
      final basePath = parentPath.isEmpty 
          ? '${client.databasePath}/documents' 
          : client.documentPath(parentPath);
      
      
      final response = await client.firestore.projects.databases.documents.list(
        basePath,
        collectionPath.collectionId!,
        pageSize: limit,
      );

      if (response.documents != null) {
        for (final doc in response.documents!) {
          final documentPath = doc.name!.split('/').last;
          final data = RepositoryFirestoreRestApi.toJson(doc);
          data['id'] = documentPath;
          documents.add(data);
          result.addRead('${collectionPath.path}/$documentPath');

          if (verbose) {
            stdout.writeln('  Exported: ${collectionPath.path}/$documentPath');
          }
        }
      }

      if (!outputToStdout) {
        stdout.writeln('Exported ${documents.length} documents');
      }
    } on Exception catch (e) {
      result.addFailed(collectionPath.path, e.toString());
    }

    return {'data': documents};
  }

  Future<Map<String, dynamic>> _exportDocument({
    required FirestoreClient client,
    required FirestorePath documentPath,
    required OperationResult result,
  }) async {
    try {
      final fullPath = client.documentPath(documentPath.path);
      final doc = await client.firestore.projects.databases.documents.get(
        fullPath,
      );

      final data = RepositoryFirestoreRestApi.toJson(doc);
      data['id'] = documentPath.documentId;
      result.addRead(documentPath.path);

      return data;
    } on Exception catch (e) {
      result.addFailed(documentPath.path, e.toString());
      return {};
    }
  }
}
