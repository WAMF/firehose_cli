@Timeout(Duration(minutes: 5))
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers/emulator_helper.dart';
import '../helpers/test_data_helper.dart';

void main() {
  group('Emulator Auth Integration Tests', () {
    late Map<String, String> env;

    setUpAll(() async {
      await EmulatorHelper.start();
    });

    setUp(() async {
      await EmulatorHelper.clearData();
      env = {
        ...Platform.environment,
        ...EmulatorHelper.environmentVariables,
      };
    });

    group('Bearer owner mode', () {
      test('bypasses security rules and allows writes to protected paths',
          () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'Bearer Owner Test',
          age: 25,
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
              'auth_test/bearer_owner',
              '--file',
              inputFile.path,
              '--apply',
            ],
            environment: env,
          );

          expect(writeResult.exitCode, equals(0));
          expect(
            writeResult.stderr.toString(),
            contains('Emulator auth: Bypassing security rules (Bearer owner)'),
          );
          expect(writeResult.stdout.toString(), contains('Created: 1'));

          final exportResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'export',
              '--path',
              'auth_test/bearer_owner',
            ],
            environment: env,
          );

          expect(exportResult.exitCode, equals(0));
          final exportedData = jsonDecode(exportResult.stdout.toString());
          expect(exportedData['name'], equals('Bearer Owner Test'));
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });
    });

    group('Custom auth token mode', () {
      test('sends custom token and allows writes to protected paths', () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'Custom Token Test',
          age: 30,
        );
        final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

        try {
          final customEnv = Map<String, String>.from(env);
          customEnv['FIREHOSE_EMULATOR_AUTH_TOKEN'] = 'test-user-123';

          final writeResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'single',
              '--path',
              'auth_test/custom_token',
              '--file',
              inputFile.path,
              '--apply',
            ],
            environment: customEnv,
          );

          expect(writeResult.exitCode, equals(0));
          expect(
            writeResult.stderr.toString(),
            contains('Emulator auth: Using custom token'),
          );
          expect(writeResult.stdout.toString(), contains('Created: 1'));
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });
    });

    group('No auth mode', () {
      test('is blocked by security rules on protected paths', () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'No Auth Protected',
          age: 35,
        );
        final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

        try {
          final noAuthEnv = Map<String, String>.from(env);
          noAuthEnv['FIREHOSE_EMULATOR_NO_AUTH'] = 'true';

          final writeResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'single',
              '--path',
              'auth_test/no_auth_protected',
              '--file',
              inputFile.path,
              '--apply',
            ],
            environment: noAuthEnv,
          );

          expect(writeResult.exitCode, equals(0));
          expect(
            writeResult.stderr.toString(),
            contains('Emulator auth: No authentication'),
          );
          expect(writeResult.stdout.toString(), contains('Failed: 1'));
          expect(
            writeResult.stdout.toString(),
            contains('PERMISSION_DENIED'),
          );
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });

      test('succeeds on public paths without auth', () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'Public No Auth',
          age: 40,
        );
        final inputFile = await TestDataHelper.createJsonObjectFile(testDoc);

        try {
          final noAuthEnv = Map<String, String>.from(env);
          noAuthEnv['FIREHOSE_EMULATOR_NO_AUTH'] = 'true';

          final writeResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'single',
              '--path',
              'public/no_auth_allowed',
              '--file',
              inputFile.path,
              '--apply',
            ],
            environment: noAuthEnv,
          );

          expect(writeResult.exitCode, equals(0));
          expect(writeResult.stdout.toString(), contains('Created: 1'));

          final exportResult = await Process.run(
            'dart',
            [
              'run',
              'bin/firehose.dart',
              'export',
              '--path',
              'public/no_auth_allowed',
            ],
            environment: noAuthEnv,
          );

          expect(exportResult.exitCode, equals(0));
          final exportedData = jsonDecode(exportResult.stdout.toString());
          expect(exportedData['name'], equals('Public No Auth'));
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });
    });

    group('CLI flags', () {
      test('--emulator-auth-token overrides default Bearer owner', () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'CLI Flag Test',
          age: 45,
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
              'auth_test/cli_flag',
              '--file',
              inputFile.path,
              '--emulator-auth-token',
              'cli-token-456',
              '--apply',
            ],
            environment: env,
          );

          expect(writeResult.exitCode, equals(0));
          expect(
            writeResult.stderr.toString(),
            contains('Emulator auth: Using custom token'),
          );
          expect(writeResult.stdout.toString(), contains('Created: 1'));
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });

      test('--emulator-no-auth gets denied on protected paths', () async {
        final testDoc = TestDataHelper.createTestDocument(
          name: 'CLI No Auth Test',
          age: 50,
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
              'auth_test/cli_no_auth',
              '--file',
              inputFile.path,
              '--emulator-no-auth',
              '--apply',
            ],
            environment: env,
          );

          expect(writeResult.exitCode, equals(0));
          expect(
            writeResult.stderr.toString(),
            contains('Emulator auth: No authentication'),
          );
          expect(writeResult.stdout.toString(), contains('Failed: 1'));
        } finally {
          await TestDataHelper.cleanupTempFiles(inputFile);
        }
      });
    });
  });
}
