@Timeout(Duration(minutes: 5))
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'helpers/emulator_helper.dart';
import 'helpers/test_data_helper.dart';

void main() {
  setUpAll(() async {
    print('Starting emulator for all integration tests...');
    await EmulatorHelper.start();
  });

  tearDownAll(() async {
    print('Stopping emulator after all integration tests...');
    await EmulatorHelper.stop();
  });

  group('Integration Tests', () {
    late Map<String, String> env;

    setUp(() async {
      await EmulatorHelper.clearData();
      env = {
        ...Platform.environment,
        ...EmulatorHelper.environmentVariables,
      };
    });

    test('single document write and export', () async {
      final testDoc = TestDataHelper.createTestDocument(
        name: 'John Doe',
        age: 30,
      );
      final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

      try {
        // Write document
        final writeResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'single',
           '--path', 'test_users/test_user',
           '--file', inputFile.path,
           '--apply'],
          environment: env,
        );

        print('Write - Exit Code: ${writeResult.exitCode}');
        print('Write - STDOUT: ${writeResult.stdout}');
        print('Write - STDERR: ${writeResult.stderr}');

        expect(writeResult.exitCode, equals(0));

        // Export the document to stdout
        final exportResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'export',
           '--path', 'test_users/test_user'],
          environment: env,
        );

        print('Export - Exit Code: ${exportResult.exitCode}');
        print('Export - STDOUT: ${exportResult.stdout}');
        print('Export - STDERR: ${exportResult.stderr}');

        expect(exportResult.exitCode, equals(0));
        
        final exportedData = jsonDecode(exportResult.stdout.toString());
        expect(exportedData['name'], equals('John Doe'));
        expect(exportedData['age'], equals(30));
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });

    test('import and export collections', () async {
      await EmulatorHelper.importTestData('test_data/import_collections.json');
      
      final result = await Process.run(
        'dart',
        ['run', 'bin/firehose.dart', 'export',
         '--path', 'import_test_users'],
        environment: env,
      );

      print('Export Collections - Exit Code: ${result.exitCode}');
      print('Export Collections - STDOUT: ${result.stdout}');
      print('Export Collections - STDERR: ${result.stderr}');

      expect(result.exitCode, equals(0));
      
      final exportedData = jsonDecode(result.stdout.toString());
      expect(exportedData, isA<Map>());
      expect(exportedData.length, greaterThan(0));
    });

    test('batch document operations', () async {
      final testDocs = [
        {'id': 'doc1', 'name': 'Test 1', 'value': 100},
        {'id': 'doc2', 'name': 'Test 2', 'value': 200},
        {'id': 'doc3', 'name': 'Test 3', 'value': 300},
      ];
      final batchFile = await TestDataHelper.createJsonArrayFile(testDocs);

      try {
        final result = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'batch',
           '--collection', 'test_batch',
           '--file', batchFile.path,
           '--id-field', 'id',
           '--apply'],
          environment: env,
        );

        print('Batch - Exit Code: ${result.exitCode}');
        print('Batch - STDOUT: ${result.stdout}');
        print('Batch - STDERR: ${result.stderr}');

        expect(result.exitCode, equals(0));
        
        // Verify documents were actually created by exporting the collection to stdout
        final exportResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'export',
           '--path', 'test_batch'],
          environment: env,
        );
        
        expect(exportResult.exitCode, equals(0));
        
        final exportedData = jsonDecode(exportResult.stdout.toString());
        
        // Collection export returns {"data": [array of docs]}
        expect(exportedData, isA<Map>());
        expect(exportedData['data'], isA<List>());
        final docs = exportedData['data'] as List;
        expect(docs.length, equals(3));
        
        // Create a map for easier verification
        final docsMap = <String, dynamic>{};
        for (final doc in docs) {
          docsMap[doc['id']] = doc;
        }
        
        expect(docsMap['doc1']?['name'], equals('Test 1'));
        expect(docsMap['doc1']?['value'], equals(100));
        expect(docsMap['doc2']?['name'], equals('Test 2'));
        expect(docsMap['doc2']?['value'], equals(200));
        expect(docsMap['doc3']?['name'], equals('Test 3'));
        expect(docsMap['doc3']?['value'], equals(300));
      } finally {
        await TestDataHelper.cleanupTempFiles(batchFile);
      }
    });

    test('document merge operation', () async {
      final initialDoc = {'name': 'Initial', 'field1': 'value1'};
      final mergeDoc = {'field2': 'value2', 'field3': 'value3'};
      
      final initialFile = await TestDataHelper.createJsonObjectFile(initialDoc);
      final mergeFile = await TestDataHelper.createJsonObjectFile(mergeDoc);

      try {
        // Create initial document
        var result = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'single',
           '--path', 'test_merge/doc1',
           '--file', initialFile.path,
           '--apply'],
          environment: env,
        );
        print('Initial Doc - Exit Code: ${result.exitCode}');
        print('Initial Doc - STDOUT: ${result.stdout}');
        print('Initial Doc - STDERR: ${result.stderr}');

        expect(result.exitCode, equals(0));

        // Merge additional fields
        result = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'single',
           '--path', 'test_merge/doc1',
           '--file', mergeFile.path,
           '--merge',
           '--apply'],
          environment: env,
        );
        print('Merge - Exit Code: ${result.exitCode}');
        print('Merge - STDOUT: ${result.stdout}');
        print('Merge - STDERR: ${result.stderr}');

        expect(result.exitCode, equals(0));

        // Export and verify merge using stdout
        result = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'export',
           '--path', 'test_merge/doc1'],
          environment: env,
        );
        
        print('Export Merged - Exit Code: ${result.exitCode}');
        print('Export Merged - STDOUT: ${result.stdout}');
        print('Export Merged - STDERR: ${result.stderr}');

        expect(result.exitCode, equals(0));
        final exported = jsonDecode(result.stdout.toString());
        expect(exported['name'], equals('Initial'));
        expect(exported['field1'], equals('value1'));
        expect(exported['field2'], equals('value2'));
        expect(exported['field3'], equals('value3'));
      } finally {
        await TestDataHelper.cleanupTempFiles(initialFile);
        await TestDataHelper.cleanupTempFiles(mergeFile);
      }
    });

    test('export to stdout', () async {
      final testDoc = TestDataHelper.createTestDocument(
        name: 'Stdout Test',
        age: 25,
      );
      final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

      try {
        // Write document first
        final writeResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'single',
           '--path', 'test_stdout/doc1',
           '--file', inputFile.path,
           '--apply'],
          environment: env,
        );

        expect(writeResult.exitCode, equals(0));

        // Export to stdout (no --output parameter)
        final exportResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'export',
           '--path', 'test_stdout/doc1'],
          environment: env,
        );

        print('Export to stdout - Exit Code: ${exportResult.exitCode}');
        print('Export to stdout - STDOUT: ${exportResult.stdout}');
        print('Export to stdout - STDERR: ${exportResult.stderr}');

        expect(exportResult.exitCode, equals(0));
        
        // Parse the JSON from stdout
        final jsonOutput = exportResult.stdout.toString();
        final exportedData = jsonDecode(jsonOutput);
        
        // Verify the data matches what we wrote
        expect(exportedData['name'], equals('Stdout Test'));
        expect(exportedData['age'], equals(25));
        
        // Verify no extraneous output (should be valid JSON)
        expect(() => jsonDecode(jsonOutput), returnsNormally);
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });

    test('dry run mode validation', () async {
      final testDoc = {'test': 'dry_run'};
      final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

      try {
        // Run without --apply flag (dry run mode)
        final result = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'single',
           '--path', 'test_dryrun/doc1',
           '--file', inputFile.path],
          environment: env,
        );

        print('Dry Run - Exit Code: ${result.exitCode}');
        print('Dry Run - STDOUT: ${result.stdout}');
        print('Dry Run - STDERR: ${result.stderr}');

        // Dry run mode returns exit code 0 but shows DRY RUN MODE message
        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('DRY RUN MODE'));

        // Verify the document was NOT written by trying to export it
        final exportResult = await Process.run(
          'dart',
          ['run', 'bin/firehose.dart', 'export',
           '--path', 'test_dryrun/doc1'],
          environment: env,
        );

        print('Export Check - Exit Code: ${exportResult.exitCode}');
        print('Export Check - STDOUT: ${exportResult.stdout}');
        print('Export Check - STDERR: ${exportResult.stderr}');

        // Check if the export returned empty data for non-existent document
        final exportedData = jsonDecode(exportResult.stdout.toString());
        expect(exportedData, isEmpty,
            reason: 'Export should return empty data for non-existent document');
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });
  });
}