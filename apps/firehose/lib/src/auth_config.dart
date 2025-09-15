import 'package:firehose/src/environment.dart';

/// Configuration for authentication options
/// This class manages command-line overrides for environment configuration
class AuthConfig {
  static const _projectIdKey = 'FIREHOSE_PROJECT_ID';
  static const _emulatorHostKey = 'FIRESTORE_EMULATOR_HOST';
  static const _serviceAccountKey = 'FIREHOSE_SERVICE_ACCOUNT';
  static const _clientIdKey = 'FIREHOSE_CLIENT_ID';
  static const _clientSecretKey = 'FIREHOSE_CLIENT_SECRET';
  /// Creates an AuthConfig instance
  AuthConfig({
    this.projectId,
    this.emulatorHost,
    this.serviceAccount,
    this.clientId,
    this.clientSecret,
    this.useAdc = false,
  });

  /// Google Cloud project ID
  final String? projectId;
  
  /// Firestore emulator host (e.g., localhost:8080)
  final String? emulatorHost;
  
  /// Service account JSON string
  final String? serviceAccount;
  
  /// OAuth2 client ID
  final String? clientId;
  
  /// OAuth2 client secret
  final String? clientSecret;
  
  /// Whether to use Application Default Credentials
  final bool useAdc;
  
  /// Override environment variables with command-line configuration values
  void overrideEnvironmentVariables() {
    if (projectId != null) {
      _setOverride(_projectIdKey, projectId!);
    }
    if (emulatorHost != null) {
      _setOverride(_emulatorHostKey, emulatorHost!);
    }
    if (serviceAccount != null) {
      _setOverride(_serviceAccountKey, serviceAccount!);
    }
    if (clientId != null) {
      _setOverride(_clientIdKey, clientId!);
    }
    if (clientSecret != null) {
      _setOverride(_clientSecretKey, clientSecret!);
    }
    if (useAdc) {
      // Clear other auth methods to force ADC
      _removeOverride(_serviceAccountKey);
      _removeOverride(_clientIdKey);
      _removeOverride(_clientSecretKey);
    }
  }
  
  // Store command-line overrides separately from environment
  static final Map<String, String> _cliOverrides = {};
  
  static void _setOverride(String key, String value) {
    _cliOverrides[key] = value;
  }
  
  static void _removeOverride(String key) {
    _cliOverrides.remove(key);
  }
  
  /// Get configuration value with CLI overrides taking precedence
  /// Priority: CLI args > .env file > system environment
  static String? getConfigValue(String key) {
    // First check CLI overrides
    if (_cliOverrides.containsKey(key)) {
      return _cliOverrides[key];
    }
    // Then use Environment class which checks .env and system env
    return Environment().get(key);
  }
}
