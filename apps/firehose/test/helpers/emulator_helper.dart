import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class EmulatorHelper {
  static const String defaultHost = 'localhost:8090';
  static const String defaultProjectId = 'test-project';
  static const Duration startupTimeout = Duration(seconds: 30);
  static const Duration checkInterval = Duration(milliseconds: 500);

  static Process? _emulatorProcess;
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static Future<void> start() async {
    if (_isRunning) {
      print('Emulator already running');
      return;
    }

    // Check if emulator is already running (e.g., via firebase emulators:exec)
    final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      print('Firestore emulator detected at $emulatorHost');
      // Verify it's actually accessible
      try {
        final response = await http
            .get(Uri.parse('http://$emulatorHost'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          _isRunning = true;
          print('Confirmed emulator is accessible at $emulatorHost');
          return;
        }
      } catch (e) {
        print('Emulator host set but not accessible: $e');
        // Fall through to start our own
      }
    }

    await Process.run('pkill', ['-f', 'firebase emulators']);
    await Process.run('pkill', ['-f', 'java.*firestore']);
    await Future<void>.delayed(const Duration(seconds: 2));

    print('Starting Firestore emulator...');
    _emulatorProcess = await Process.start(
      'firebase',
      ['emulators:start', '--only', 'firestore', '--project', defaultProjectId],
      environment: {
        ...Platform.environment,
        'FIRESTORE_EMULATOR_HOST': defaultHost,
      },
    );

    _emulatorProcess!.stdout.transform(utf8.decoder).listen((data) {
      if (data.contains('All emulators ready')) {
        _isRunning = true;
      }
    });

    _emulatorProcess!.stderr.transform(utf8.decoder).listen((data) {
      print('Emulator error: $data');
    });

    await _waitForEmulator();
    print('Firestore emulator started successfully');
  }

  static Future<void> _waitForEmulator() async {
    final startTime = DateTime.now();
    
    while (!_isRunning) {
      if (DateTime.now().difference(startTime) > startupTimeout) {
        throw TimeoutException('Emulator failed to start within timeout');
      }

      try {
        final response = await http
            .get(Uri.parse('http://$defaultHost'))
            .timeout(const Duration(seconds: 1));
        
        if (response.statusCode == 200) {
          _isRunning = true;
          return;
        }
      } catch (_) {
      }

      await Future<void>.delayed(checkInterval);
    }
  }

  static Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    // Don't stop if we didn't start it (e.g., running via firebase emulators:exec)
    if (_emulatorProcess == null) {
      print('Emulator managed externally, not stopping');
      return;
    }

    print('Stopping Firestore emulator...');
    _emulatorProcess?.kill();
    await Future<void>.delayed(const Duration(seconds: 2));
    _isRunning = false;
    _emulatorProcess = null;
    print('Firestore emulator stopped');
  }

  static Future<void> clearData() async {
    if (!_isRunning) {
      // If not running, assume it's managed externally and skip
      return;
    }

    final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'] ?? defaultHost;
    
    try {
      final response = await http.delete(
        Uri.parse(
          'http://$emulatorHost/emulator/v1/projects/$defaultProjectId/databases/(default)/documents',
        ),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        throw Exception('Failed to clear emulator data: ${response.body}');
      }
    } catch (e) {
      print('Warning: Could not clear emulator data: $e');
    }
  }

  static Map<String, String> get environmentVariables {
    final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    return {
      'FIREHOSE_PROJECT_ID': defaultProjectId,
      'FIRESTORE_EMULATOR_HOST': emulatorHost ?? defaultHost,
    };
  }

  static Future<void> importTestData(String dataFilePath) async {
    // Check if emulator is available (either we started it or it's external)
    final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (!_isRunning && (emulatorHost == null || emulatorHost.isEmpty)) {
      throw StateError('Emulator is not running');
    }

    print('Importing test data from $dataFilePath...');
    
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(environmentVariables);

    final result = await Process.run(
      'dart',
      ['run', 'bin/firehose.dart',
        'import',
        '--file',
        dataFilePath,
        '--apply',
        '--verbose',
      ],
      environment: env,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to import test data: ${result.stderr}');
    }
    
    print('Test data imported successfully');
  }
}