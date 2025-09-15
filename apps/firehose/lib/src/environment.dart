import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Manages environment configuration from both .env files and environment variables
class Environment {
  static final Environment _instance = Environment._internal();

  factory Environment() => _instance;

  Environment._internal();

  late final DotEnv _dotEnv;
  bool _isLoaded = false;

  static const _maxParentDirectorySearchDepth = 5;
  static const _envFileName = '.env';
  static const _trueValue = 'true';

  /// Load environment configuration from .env file if it exists
  void load({String? path}) {
    if (_isLoaded) return;

    final envPath = path ?? _findEnvFile();
    if (envPath != null) {
      _dotEnv = DotEnv(includePlatformEnvironment: true)..load([envPath]);
    } else {
      // No .env file found, just use platform environment
      _dotEnv = DotEnv(includePlatformEnvironment: true);
    }
    _isLoaded = true;
  }

  /// Find .env file in current directory or parent directories
  String? _findEnvFile() {
    Directory current = Directory.current;

    // Check up to 5 parent directories
    for (int i = 0; i < _maxParentDirectorySearchDepth; i++) {
      final envFile = File('${current.path}/$_envFileName');
      if (envFile.existsSync()) {
        return envFile.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) break; // Reached root
      current = parent;
    }

    return null;
  }
  
  /// Get a value from environment (checks .env file first, then system environment)
  String? get(String key) {
    if (!_isLoaded) load();
    return _dotEnv[key];
  }
  
  /// Get a value or return a default if not found
  String getOrDefault(String key, String defaultValue) {
    return get(key) ?? defaultValue;
  }
  
  /// Check if a key exists in the environment
  bool has(String key) {
    if (!_isLoaded) load();
    return _dotEnv[key] != null;
  }
  
  /// Get all environment variables as a map
  Map<String, String> get all {
    if (!_isLoaded) load();
    // Since map is private, we'll collect the keys we care about
    final result = <String, String>{};
    final keys = [
      _EnvKeys.projectId,
      _EnvKeys.emulatorHost,
      _EnvKeys.serviceAccount,
      _EnvKeys.clientId,
      _EnvKeys.clientSecret,
      _EnvKeys.useAdc,
    ];

    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  // Convenience getters for common Firehose environment variables
  String? get projectId => get(_EnvKeys.projectId);
  String? get emulatorHost => get(_EnvKeys.emulatorHost);
  String? get serviceAccountPath => get(_EnvKeys.serviceAccount);
  String? get clientId => get(_EnvKeys.clientId);
  String? get clientSecret => get(_EnvKeys.clientSecret);
  bool get useAdc => get(_EnvKeys.useAdc)?.toLowerCase() == _trueValue;
}

class _EnvKeys {
  static const projectId = 'FIREHOSE_PROJECT_ID';
  static const emulatorHost = 'FIRESTORE_EMULATOR_HOST';
  static const serviceAccount = 'FIREHOSE_SERVICE_ACCOUNT';
  static const clientId = 'FIREHOSE_CLIENT_ID';
  static const clientSecret = 'FIREHOSE_CLIENT_SECRET';
  static const useAdc = 'FIREHOSE_USE_ADC';
}