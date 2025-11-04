import 'dart:io';

import 'package:firehose_cli/src/config_manager.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:kiss_firebase_repository_rest/kiss_firebase_repository_rest.dart';

/// Manages Firestore client configuration and connection
class FirestoreClient {
  FirestoreClient._({
    required this.projectId,
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

  /// Google API scope for Firestore/Datastore access.
  static const String _datastoreScope = 'https://www.googleapis.com/auth/datastore';

  /// The Google Cloud project ID.
  final String projectId;

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

    final emulatorHost = ConfigManager.get(emulatorHostEnvVar);
    final googleClient = await _createGoogleClient();
    final httpClient = await googleClient.getClient();

    // If emulator host is set, use it
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      stdout.writeln('Using Firestore emulator at $emulatorHost');
      return FirestoreClient._(
        projectId: projectId,
        firestore: FirestoreApi(httpClient, rootUrl: 'http://$emulatorHost/'),
      );
    }

    return FirestoreClient._(
      projectId: projectId,
      firestore: FirestoreApi(httpClient),
    );
  }

  static Future<GoogleClient> _createGoogleClient() async {
    // ConfigManager.get now handles priority: CLI > .env > system env
    final emulatorHost = ConfigManager.get(emulatorHostEnvVar);
    final serviceAccountJson = ConfigManager.get(serviceAccountEnvVar);
    final clientId = ConfigManager.get(clientIdEnvVar);
    final clientSecret = ConfigManager.get(clientSecretEnvVar);

    // If emulator is configured, use unauthenticated client
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      stdout.writeln('Using unauthenticated client for emulator');
      return GoogleClient.unauthenticated();
    }

    if (serviceAccountJson != null && serviceAccountJson.isNotEmpty) {
      stdout.writeln('Using service account authentication');
      return GoogleClient(
        serviceAccountJson: serviceAccountJson,
        scopes: [_datastoreScope],
      );
    } else if (clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty) {
      stdout.writeln('Using OAuth2 user consent authentication');
      return GoogleClient.userConsent(
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: [_datastoreScope],
      );
    } else {
      stdout.writeln('Using Application Default Credentials');
      return GoogleClient.defaultCredentials(
        scopes: [_datastoreScope],
      );
    }
  }

  /// Gets the database path for this project.
  String get databasePath => 'projects/$projectId/databases/(default)';

  /// Gets the full document path for a given relative path.
  String documentPath(String path) => '$databasePath/documents/$path';
}
