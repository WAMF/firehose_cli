import 'package:firehose/src/config_manager.dart';

/// Authentication-specific configuration utilities
class AuthConfigExtension {
  static const _projectIdKey = 'FIREHOSE_PROJECT_ID';
  static const _emulatorHostKey = 'FIRESTORE_EMULATOR_HOST';
  static const _serviceAccountKey = 'FIREHOSE_SERVICE_ACCOUNT';
  static const _clientIdKey = 'FIREHOSE_CLIENT_ID';
  static const _clientSecretKey = 'FIREHOSE_CLIENT_SECRET';

  /// Set authentication-related configuration overrides
  static void setAuthenticationOverrides({
    String? projectId,
    String? emulatorHost,
    String? serviceAccount,
    String? clientId,
    String? clientSecret,
  }) {
    if (projectId != null) {
      ConfigManager.setOverride(_projectIdKey, projectId);
    }
    if (emulatorHost != null) {
      ConfigManager.setOverride(_emulatorHostKey, emulatorHost);
    }
    if (serviceAccount != null) {
      ConfigManager.setOverride(_serviceAccountKey, serviceAccount);
    }
    if (clientId != null) {
      ConfigManager.setOverride(_clientIdKey, clientId);
    }
    if (clientSecret != null) {
      ConfigManager.setOverride(_clientSecretKey, clientSecret);
    }
  }
}