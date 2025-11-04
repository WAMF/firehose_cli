import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firehose_cli/commands/batch_command.dart';
import 'package:firehose_cli/commands/export_command.dart';
import 'package:firehose_cli/commands/import_command.dart';
import 'package:firehose_cli/commands/single_command.dart';
import 'package:firehose_cli/src/config_extensions.dart';
import 'package:firehose_cli/src/environment.dart';

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
      help: 'Path to service account JSON file (includes project_id)',
    )
    ..addOption(
      'client-id',
      help: 'OAuth2 client ID for user consent flow',
    )
    ..addOption(
      'client-secret',
      help: 'OAuth2 client secret for user consent flow',
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
    String? extractedProjectId;
    if (results['service-account'] != null) {
      final file = File(results['service-account'] as String);
      if (!file.existsSync()) {
        stderr.writeln('Service account file not found: ${results['service-account']}');
        exit(1);
      }
      serviceAccountJson = file.readAsStringSync();

      // Extract project ID from service account JSON if not provided via CLI
      if (results['project-id'] == null) {
        try {
          final serviceAccountData = json.decode(serviceAccountJson) as Map<String, dynamic>;
          extractedProjectId = serviceAccountData['project_id'] as String?;
        } catch (e) {
          stderr.writeln('Error parsing service account JSON: $e');
        }
      }
    }

    AuthConfigExtension.setAuthenticationOverrides(
      projectId: results['project-id'] as String? ?? extractedProjectId,
      emulatorHost: results['emulator-host'] as String?,
      serviceAccount: serviceAccountJson,
      clientId: results['client-id'] as String?,
      clientSecret: results['client-secret'] as String?,
    );
    
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
