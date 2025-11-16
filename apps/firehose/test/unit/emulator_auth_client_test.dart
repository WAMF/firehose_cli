import 'package:firehose_cli/src/emulator_auth_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('EmulatorAuthClient', () {
    test('adds Bearer owner header in bypassRules mode', () async {
      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('{}', 200);
      });

      final client = EmulatorAuthClient(
        innerClient: mockClient,
        authMode: EmulatorAuthMode.bypassRules,
      );

      await client.get(Uri.parse('http://localhost:8090/test'));

      expect(capturedAuthHeader, equals('Bearer owner'));
    });

    test('adds custom Bearer token in customToken mode', () async {
      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('{}', 200);
      });

      final client = EmulatorAuthClient(
        innerClient: mockClient,
        authMode: EmulatorAuthMode.customToken,
        customToken: 'test-user-123',
      );

      await client.get(Uri.parse('http://localhost:8090/test'));

      expect(capturedAuthHeader, equals('Bearer test-user-123'));
    });

    test('adds no auth header in noAuth mode', () async {
      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('{}', 200);
      });

      final client = EmulatorAuthClient(
        innerClient: mockClient,
        authMode: EmulatorAuthMode.noAuth,
      );

      await client.get(Uri.parse('http://localhost:8090/test'));

      expect(capturedAuthHeader, isNull);
    });

    test('throws when customToken mode used without token', () {
      final mockClient = MockClient((request) async {
        return http.Response('{}', 200);
      });

      expect(
        () => EmulatorAuthClient(
          innerClient: mockClient,
          authMode: EmulatorAuthMode.customToken,
        ),
        throwsArgumentError,
      );
    });

    test('preserves other headers when adding auth', () async {
      Map<String, String>? capturedHeaders;
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final client = EmulatorAuthClient(
        innerClient: mockClient,
        authMode: EmulatorAuthMode.bypassRules,
      );

      await client.get(
        Uri.parse('http://localhost:8090/test'),
        headers: {'X-Custom': 'value'},
      );

      expect(capturedHeaders?['Authorization'], equals('Bearer owner'));
      expect(capturedHeaders?['X-Custom'], equals('value'));
    });

    test('handles POST requests with body', () async {
      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('{}', 200);
      });

      final client = EmulatorAuthClient(
        innerClient: mockClient,
        authMode: EmulatorAuthMode.bypassRules,
      );

      await client.post(
        Uri.parse('http://localhost:8090/test'),
        body: '{"test": true}',
      );

      expect(capturedAuthHeader, equals('Bearer owner'));
    });
  });
}
