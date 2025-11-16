import 'package:firehose_cli/src/config_manager.dart';

/// Authentication-specific configuration utilities
class AuthConfigExtension {
  static const _projectIdKey = 'FIREHOSE_PROJECT_ID';
  static const _emulatorHostKey = 'FIRESTORE_EMULATOR_HOST';
  static const _emulatorAuthTokenKey = 'FIREHOSE_EMULATOR_AUTH_TOKEN';
  static const _emulatorNoAuthKey = 'FIREHOSE_EMULATOR_NO_AUTH';
  static const _serviceAccountKey = 'FIREHOSE_SERVICE_ACCOUNT';
  static const _clientIdKey = 'FIREHOSE_CLIENT_ID';
  static const _clientSecretKey = 'FIREHOSE_CLIENT_SECRET';

  /// Set authentication-related configuration overrides
  static void setAuthenticationOverrides({
    String? projectId,
    String? emulatorHost,
    String? emulatorAuthToken,
    bool? emulatorNoAuth,
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
    if (emulatorAuthToken != null) {
      ConfigManager.setOverride(_emulatorAuthTokenKey, emulatorAuthToken);
    }
    if (emulatorNoAuth != null && emulatorNoAuth) {
      ConfigManager.setOverride(_emulatorNoAuthKey, 'true');
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