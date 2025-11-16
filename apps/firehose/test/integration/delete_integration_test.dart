@Timeout(Duration(minutes: 5))
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../helpers/emulator_helper.dart';
import '../helpers/test_data_helper.dart';

void main() {
  setUpAll(() async {
    await EmulatorHelper.start();
  });

  tearDownAll(() async {
    await EmulatorHelper.stop();
  });

  group('Delete Command Integration Tests', () {
    late Map<String, String> env;

    setUp(() async {
      await EmulatorHelper.clearData();
      env = {
        ...Platform.environment,
        ...EmulatorHelper.environmentVariables,
      };
    });

    test('delete single document', () async {
      final testDoc = TestDataHelper.createTestDocument(
        name: 'John Doe',
        age: 30,
      );
      final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

      try {
        final writeResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'single',
            '--path',
            'test_users/test_user',
            '--file',
            inputFile.path,
            '--apply',
          ],
          environment: env,
        );

        expect(writeResult.exitCode, equals(0));

        final deleteResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'delete',
            '--path',
            'test_users/test_user',
            '--apply',
          ],
          environment: env,
        );

        expect(deleteResult.exitCode, equals(0));
        expect(deleteResult.stdout.toString(), contains('Deleted: 1'));

        final exportResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'export',
            '--path',
            'test_users/test_user',
          ],
          environment: env,
        );

        expect(exportResult.exitCode, equals(1));
        expect(exportResult.stdout.toString().trim(), equals('{}'));
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });

    test('delete dry-run mode', () async {
      final testDoc = TestDataHelper.createTestDocument(
        name: 'Jane Doe',
        age: 25,
      );
      final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

      try {
        await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'single',
            '--path',
            'test_users/test_user_dry',
            '--file',
            inputFile.path,
            '--apply',
          ],
          environment: env,
        );

        final deleteResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'delete',
            '--path',
            'test_users/test_user_dry',
          ],
          environment: env,
        );

        expect(deleteResult.exitCode, equals(0));
        expect(deleteResult.stdout.toString(), contains('DRY RUN MODE'));

        final exportResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'export',
            '--path',
            'test_users/test_user_dry',
          ],
          environment: env,
        );

        expect(exportResult.exitCode, equals(0));
        final exportedData = jsonDecode(exportResult.stdout.toString());
        expect(exportedData['name'], equals('Jane Doe'));
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });

    test('delete collection recursively', () async {
      final testDocs = [
        {'id': 'doc1', 'name': 'Test 1', 'value': 100},
        {'id': 'doc2', 'name': 'Test 2', 'value': 200},
        {'id': 'doc3', 'name': 'Test 3', 'value': 300},
      ];
      final inputFile = await TestDataHelper.createJsonArrayFile(testDocs);

      try {
        await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'batch',
            '--collection',
            'test_collection',
            '--file',
            inputFile.path,
            '--id-field',
            'id',
            '--apply',
          ],
          environment: env,
        );

        final deleteResult = await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'delete',
            '--path',
            'test_collection',
            '--recursive',
            '--apply',
          ],
          environment: env,
        );

        expect(deleteResult.exitCode, equals(0));
        expect(deleteResult.stdout.toString(), contains('Deleted: 3'));
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });

    test('delete collection without recursive flag fails', () async {
      final deleteResult = await Process.run(
        'dart',
        [
          'run',
          'bin/firehose.dart',
          'delete',
          '--path',
          'test_collection',
          '--apply',
        ],
        environment: env,
      );

      expect(deleteResult.exitCode, equals(2));
      expect(
        deleteResult.stderr.toString(),
        contains('Use --recursive to delete all documents in collection'),
      );
    });

    test('batch delete from file', () async {
      final testDocs = [
        {'id': 'batch1', 'name': 'Batch 1'},
        {'id': 'batch2', 'name': 'Batch 2'},
        {'id': 'batch3', 'name': 'Batch 3'},
      ];
      final inputFile = await TestDataHelper.createJsonArrayFile(testDocs);

      try {
        await Process.run(
          'dart',
          [
            'run',
            'bin/firehose.dart',
            'batch',
            '--collection',
            'batch_test',
            '--file',
            inputFile.path,
            '--id-field',
            'id',
            '--apply',
          ],
          environment: env,
        );

        final deletePaths = [
          'batch_test/batch1',
          'batch_test/batch2',
        ];
        final deleteFile = await TestDataHelper.createJsonArrayFile(deletePaths);

        try {
          final deleteResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'delete',
              '--path',
              'batch_test',
              '--file',
              deleteFile.path,
              '--apply',
            ],
            environment: env,
          );

          expect(deleteResult.exitCode, equals(0));
          expect(deleteResult.stdout.toString(), contains('Deleted: 2'));
        } finally {
          await TestDataHelper.cleanupTempFiles(deleteFile);
        }
      } finally {
        await TestDataHelper.cleanupTempFiles(inputFile);
      }
    });
  });
}
