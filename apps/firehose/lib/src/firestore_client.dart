import 'dart:io';

import 'package:firehose/src/auth_config.dart';
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

  /// The Google Cloud project ID.
  final String projectId;

  /// The Firestore API client.
  final FirestoreApi firestore;

  /// Creates a Firestore client from environment configuration
  static Future<FirestoreClient> fromEnvironment() async {
    final projectId = AuthConfig.getEnv(projectIdEnvVar);
    if (projectId == null || projectId.isEmpty) {
      throw StateError(
        'Project ID not set. Set $projectIdEnvVar environment variable.',
      );
    }

    final emulatorHost = AuthConfig.getEnv(emulatorHostEnvVar);
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
    final emulatorHost = AuthConfig.getEnv(emulatorHostEnvVar);
    final serviceAccountJson = AuthConfig.getEnv(serviceAccountEnvVar);
    final clientId = AuthConfig.getEnv(clientIdEnvVar);
    final clientSecret = AuthConfig.getEnv(clientSecretEnvVar);

    // If emulator is configured, use unauthenticated client
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      stdout.writeln('Using unauthenticated client for emulator');
      return GoogleClient.unauthenticated();
    }

    if (serviceAccountJson != null && serviceAccountJson.isNotEmpty) {
      stdout.writeln('Using service account authentication');
      return GoogleClient(
        serviceAccountJson: serviceAccountJson,
        scopes: ['https://www.googleapis.com/auth/datastore'],
      );
    } else if (clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty) {
      stdout.writeln('Using OAuth2 user consent authentication');
      return GoogleClient.userConsent(
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: ['https://www.googleapis.com/auth/datastore'],
      );
    } else {
      stdout.writeln('Using Application Default Credentials');
      return GoogleClient.defaultCredentials(
        scopes: ['https://www.googleapis.com/auth/datastore'],
      );
    }
  }

  /// Gets the database path for this project.
  String get databasePath => 'projects/$projectId/databases/(default)';

  /// Gets the full document path for a given relative path.
  String documentPath(String path) => '$databasePath/documents/$path';
}
