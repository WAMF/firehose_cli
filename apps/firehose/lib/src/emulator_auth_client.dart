import 'dart:async';

import 'package:http/http.dart' as http;

enum EmulatorAuthMode {
  bypassRules,
  customToken,
  noAuth,
}

class EmulatorAuthClient extends http.BaseClient {
  EmulatorAuthClient({
    required http.Client innerClient,
    required this.authMode,
    this.customToken,
  }) : _innerClient = innerClient {
    if (authMode == EmulatorAuthMode.customToken && customToken == null) {
      throw ArgumentError(
        'customToken must be provided when authMode is customToken',
      );
    }
  }

  final http.Client _innerClient;
  final EmulatorAuthMode authMode;
  final String? customToken;

  static const String _ownerToken = 'owner';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final modifiedRequest = _addAuthHeader(request);
    return _innerClient.send(modifiedRequest);
  }

  http.BaseRequest _addAuthHeader(http.BaseRequest request) {
    final authHeader = _getAuthorizationHeader();
    if (authHeader == null) {
      return request;
    }

    request.headers['Authorization'] = authHeader;
    return request;
  }

  String? _getAuthorizationHeader() {
    switch (authMode) {
      case EmulatorAuthMode.bypassRules:
        return 'Bearer $_ownerToken';
      case EmulatorAuthMode.customToken:
        return 'Bearer $customToken';
      case EmulatorAuthMode.noAuth:
        return null;
    }
  }

  @override
  void close() {
    _innerClient.close();
  }
}
