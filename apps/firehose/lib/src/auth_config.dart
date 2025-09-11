import 'dart:io';

/// Configuration for authentication options
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
  
  /// Apply this configuration to environment variables
  void applyToEnvironment() {
    if (projectId != null) {
      _setEnv('FIREHOSE_PROJECT_ID', projectId!);
    }
    if (emulatorHost != null) {
      _setEnv('FIRESTORE_EMULATOR_HOST', emulatorHost!);
    }
    if (serviceAccount != null) {
      _setEnv('FIREHOSE_SERVICE_ACCOUNT', serviceAccount!);
    }
    if (clientId != null) {
      _setEnv('FIREHOSE_CLIENT_ID', clientId!);
    }
    if (clientSecret != null) {
      _setEnv('FIREHOSE_CLIENT_SECRET', clientSecret!);
    }
    if (useAdc) {
      // Clear other auth methods to force ADC
      _removeEnv('FIREHOSE_SERVICE_ACCOUNT');
      _removeEnv('FIREHOSE_CLIENT_ID');
      _removeEnv('FIREHOSE_CLIENT_SECRET');
    }
  }
  
  // Helper to set environment variable (using a map since Platform.environment is read-only)
  static final Map<String, String> _envOverrides = {};
  
  static void _setEnv(String key, String value) {
    _envOverrides[key] = value;
  }
  
  static void _removeEnv(String key) {
    _envOverrides.remove(key);
  }
  
  /// Get environment variable with overrides
  static String? getEnv(String key) {
    return _envOverrides[key] ?? Platform.environment[key];
  }
}
