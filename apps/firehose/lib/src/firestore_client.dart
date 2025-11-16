import 'dart:io';

import 'package:firehose_cli/src/config_manager.dart';
import 'package:firehose_cli/src/emulator_auth_client.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:http/http.dart' as http;
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Manages Firestore client configuration and connection
class FirestoreClient {
  FirestoreClient._({
    required this.projectId,
    required this.database,
    required this.firestore,
  });

  /// Environment variable name for project ID.
  static const String projectIdEnvVar = 'FIREHOSE_PROJECT_ID';

  /// Environment variable name for service account JSON.
  static const String serviceAccountEnvVar = 'FIREHOSE_SERVICE_ACCOUNT';

  /// Environment variable name for OAuth client ID.
  static const String clientIdEnvVar = 'FIREHOSE_CLIENT_ID';

  /// Environment variable name for OAuth client secret.
  static const String clientSecretEnvVar = 'FIREHOSE_CLIENT_SECRET';

  /// Environment variable name for emulator host.
  static const String emulatorHostEnvVar = 'FIRESTORE_EMULATOR_HOST';

  /// Environment variable name for emulator auth token.
  static const String emulatorAuthTokenEnvVar = 'FIREHOSE_EMULATOR_AUTH_TOKEN';

  /// Environment variable name to disable emulator auth.
  static const String emulatorNoAuthEnvVar = 'FIREHOSE_EMULATOR_NO_AUTH';

  /// Environment variable name for database name.
  static const String databaseEnvVar = 'FIREHOSE_DATABASE';

  /// Default database name.
  static const String defaultDatabase = '(default)';

  /// Google API scope for Firestore/Datastore access.
  static const String _datastoreScope = 'https://www.googleapis.com/auth/datastore';

  /// The Google Cloud project ID.
  final String projectId;

  /// The database name.
  final String database;

  /// The Firestore API client.
  final FirestoreApi firestore;

  /// Creates a Firestore client from environment configuration
  static Future<FirestoreClient> fromEnvironment() async {
    // ConfigManager.get now handles priority: CLI > .env > system env
    final projectId = ConfigManager.get(projectIdEnvVar);
    if (projectId == null || projectId.isEmpty) {
      throw StateError(
        'Project ID not set. Set $projectIdEnvVar environment variable or in .env file.',
      );
    }

    final database = ConfigManager.get(databaseEnvVar) ?? defaultDatabase;
    final emulatorHost = ConfigManager.get(emulatorHostEnvVar);

    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      stderr.writeln('Using Firestore emulator at $emulatorHost');

      final authMode = _getEmulatorAuthMode();
      final customToken = ConfigManager.get(emulatorAuthTokenEnvVar);

      final baseClient = http.Client();
      final httpClient = EmulatorAuthClient(
        innerClient: baseClient,
        authMode: authMode,
        customToken: customToken,
      );

      _logEmulatorAuthMode(authMode, customToken);

      return FirestoreClient._(
        projectId: projectId,
        database: database,
        firestore: FirestoreApi(httpClient, rootUrl: 'http://$emulatorHost/'),
      );
    }

    final googleClient = await _createGoogleClient();
    final httpClient = await googleClient.getClient();

    return FirestoreClient._(
      projectId: projectId,
      database: database,
      firestore: FirestoreApi(httpClient),
    );
  }

  static Future<GoogleClient> _createGoogleClient() async {
    final serviceAccountJson = ConfigManager.get(serviceAccountEnvVar);
    final clientId = ConfigManager.get(clientIdEnvVar);
    final clientSecret = ConfigManager.get(clientSecretEnvVar);

    if (serviceAccountJson != null && serviceAccountJson.isNotEmpty) {
      stderr.writeln('Using service account authentication');
      return GoogleClient(
        serviceAccountJson: serviceAccountJson,
        scopes: [_datastoreScope],
      );
    } else if (clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty) {
      stderr.writeln('Using OAuth2 user consent authentication');
      return GoogleClient.userConsent(
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: [_datastoreScope],
      );
    } else {
      stderr.writeln('Using Application Default Credentials');
      return GoogleClient.defaultCredentials(
        scopes: [_datastoreScope],
      );
    }
  }

  static EmulatorAuthMode _getEmulatorAuthMode() {
    final noAuth = ConfigManager.get(emulatorNoAuthEnvVar);
    final customToken = ConfigManager.get(emulatorAuthTokenEnvVar);

    if (noAuth != null && noAuth.toLowerCase() == 'true') {
      return EmulatorAuthMode.noAuth;
    }

    if (customToken != null && customToken.isNotEmpty) {
      return EmulatorAuthMode.customToken;
    }

    return EmulatorAuthMode.bypassRules;
  }

  static void _logEmulatorAuthMode(
    EmulatorAuthMode mode,
    String? customToken,
  ) {
    switch (mode) {
      case EmulatorAuthMode.bypassRules:
        stderr.writeln('Emulator auth: Bypassing security rules (Bearer owner)');
      case EmulatorAuthMode.customToken:
        stderr.writeln(
          'Emulator auth: Using custom token (Bearer ${customToken!.substring(0, customToken.length > 10 ? 10 : customToken.length)}...)',
        );
      case EmulatorAuthMode.noAuth:
        stderr.writeln('Emulator auth: No authentication (testing unauthenticated access)');
    }
  }

  /// Gets the database path for this project.
  String get databasePath => 'projects/$projectId/databases/$database';

  /// Gets the full document path for a given relative path.
  String documentPath(String path) => '$databasePath/documents/$path';
}
