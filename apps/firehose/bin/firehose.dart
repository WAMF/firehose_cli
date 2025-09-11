import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose/commands/batch_command.dart';
import 'package:firehose/commands/export_command.dart';
import 'package:firehose/commands/import_command.dart';
import 'package:firehose/commands/single_command.dart';
import 'package:firehose/src/auth_config.dart';
import 'package:firehose/src/environment.dart';

void main(List<String> arguments) async {
  final runner =
      CommandRunner<int>(
          'firehose',
          'CLI tool for reading/writing Firestore with JSON I/O',
        )
        ..addCommand(SingleCommand())
        ..addCommand(BatchCommand())
        ..addCommand(ImportCommand())
        ..addCommand(ExportCommand());

  runner.argParser
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show version information',
    )
    ..addOption(
      'env-file',
      help: 'Path to .env file (defaults to searching current and parent directories)',
    )
    ..addOption(
      'project-id',
      help: 'Google Cloud project ID (overrides FIREHOSE_PROJECT_ID)',
    )
    ..addOption(
      'emulator-host',
      help: 'Firestore emulator host (e.g., localhost:8080)',
    )
    ..addOption(
      'service-account',
      help: 'Path to service account JSON file',
    )
    ..addOption(
      'client-id',
      help: 'OAuth2 client ID for user consent flow',
    )
    ..addOption(
      'client-secret',
      help: 'OAuth2 client secret for user consent flow',
    )
    ..addFlag(
      'use-adc',
      help: 'Use Application Default Credentials',
      negatable: false,
    );

  try {
    final results = runner.parse(arguments);

    if (results['version'] as bool) {
      print('firehose version 0.1.0');
      exit(0);
    }

    // Load environment configuration with optional custom path
    final envFilePath = results['env-file'] as String?;
    Environment().load(path: envFilePath);

    // Create and apply auth configuration
    String? serviceAccountJson;
    if (results['service-account'] != null) {
      final file = File(results['service-account'] as String);
      if (!file.existsSync()) {
        stderr.writeln('Service account file not found: ${results['service-account']}');
        exit(1);
      }
      serviceAccountJson = file.readAsStringSync();
    }
    
    AuthConfig(
      projectId: results['project-id'] as String?,
      emulatorHost: results['emulator-host'] as String?,
      serviceAccount: serviceAccountJson,
      clientId: results['client-id'] as String?,
      clientSecret: results['client-secret'] as String?,
      useAdc: results['use-adc'] as bool,
    ).applyToEnvironment();
    
    await runner.runCommand(results);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    print('\n${e.usage}');
    exit(64);
  } on Exception catch (e) {
    stderr.writeln('Unexpected error: $e');
    exit(1);
  }
}
