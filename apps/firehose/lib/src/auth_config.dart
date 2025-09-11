import 'package:firehose/src/environment.dart';

/// Configuration for authentication options
/// This class manages command-line overrides for environment configuration
class AuthConfig {
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
  
  /// Apply this configuration to environment variables (overrides)
  void applyToEnvironment() {
    if (projectId != null) {
      _setOverride('FIREHOSE_PROJECT_ID', projectId!);
    }
    if (emulatorHost != null) {
      _setOverride('FIRESTORE_EMULATOR_HOST', emulatorHost!);
    }
    if (serviceAccount != null) {
      _setOverride('FIREHOSE_SERVICE_ACCOUNT', serviceAccount!);
    }
    if (clientId != null) {
      _setOverride('FIREHOSE_CLIENT_ID', clientId!);
    }
    if (clientSecret != null) {
      _setOverride('FIREHOSE_CLIENT_SECRET', clientSecret!);
    }
    if (useAdc) {
      // Clear other auth methods to force ADC
      _removeOverride('FIREHOSE_SERVICE_ACCOUNT');
      _removeOverride('FIREHOSE_CLIENT_ID');
      _removeOverride('FIREHOSE_CLIENT_SECRET');
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
  
  /// Get environment variable with CLI overrides taking precedence
  /// Priority: CLI args > .env file > system environment
  static String? getEnv(String key) {
    // First check CLI overrides
    if (_cliOverrides.containsKey(key)) {
      return _cliOverrides[key];
    }
    // Then use Environment class which checks .env and system env
    return Environment().get(key);
  }
}
