import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Manages environment configuration from both .env files and environment variables
class Environment {
  static final Environment _instance = Environment._internal();
  
  factory Environment() => _instance;
  
  Environment._internal();
  
  late final DotEnv _dotEnv;
  bool _isLoaded = false;
  
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
    for (int i = 0; i < 5; i++) {
      final envFile = File('${current.path}/.env');
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
      'FIREHOSE_PROJECT_ID',
      'FIRESTORE_EMULATOR_HOST', 
      'FIREHOSE_SERVICE_ACCOUNT',
      'FIREHOSE_CLIENT_ID',
      'FIREHOSE_CLIENT_SECRET',
      'FIREHOSE_USE_ADC',
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
  String? get projectId => get('FIREHOSE_PROJECT_ID');
  String? get emulatorHost => get('FIRESTORE_EMULATOR_HOST');
  String? get serviceAccountPath => get('FIREHOSE_SERVICE_ACCOUNT');
  String? get clientId => get('FIREHOSE_CLIENT_ID');
  String? get clientSecret => get('FIREHOSE_CLIENT_SECRET');
  bool get useAdc => get('FIREHOSE_USE_ADC')?.toLowerCase() == 'true';
}