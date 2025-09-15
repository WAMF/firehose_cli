import 'package:firehose/src/environment.dart';

/// Manages application configuration with support for multiple override sources
/// Priority: CLI arguments > .env file > system environment variables
class ConfigManager {
  // Store command-line overrides separately from environment
  static final Map<String, String> _overrides = {};

  /// Set a configuration override (typically from CLI arguments)
  static void setOverride(String key, String value) {
    _overrides[key] = value;
  }

  /// Remove a configuration override
  static void removeOverride(String key) {
    _overrides.remove(key);
  }

  /// Clear all configuration overrides
  static void clearOverrides() {
    _overrides.clear();
  }

  /// Get configuration value with proper precedence
  /// Priority: Overrides (CLI) > .env file > system environment
  static String? get(String key) {
    // First check overrides (typically from CLI)
    if (_overrides.containsKey(key)) {
      return _overrides[key];
    }
    // Then use Environment class which checks .env and system env
    return Environment().get(key);
  }
}