## 0.3.0

* **Database Selection Support**: Added support for selecting custom Firestore databases
  * `--database` flag: Specify database name (defaults to "(default)")
  * Environment variable support: `FIREHOSE_DATABASE`
  * Enables working with named databases in addition to the default database

## 0.2.0

* **Firebase Emulator Authentication Support**: Added comprehensive authentication support for Firebase Firestore Emulator
  * `Bearer owner` mode (default): Bypasses security rules for seeding data
  * Custom token mode: Test with specific authentication tokens via `--emulator-auth-token`
  * No-auth mode: Test unauthenticated access with `--emulator-no-auth`
  * Environment variable support: `FIREHOSE_EMULATOR_AUTH_TOKEN`, `FIREHOSE_EMULATOR_NO_AUTH`
* **Improved Logging**: Separated data output (stdout) from operational logs (stderr) for cleaner JSON output
* **Test Infrastructure**: Added integration tests for emulator authentication modes with security rules validation

## 0.1.0

* Initial release
* Four commands for Firestore data management:
  * `single` - Write one document from a JSON file
  * `batch` - Write multiple documents to one collection
  * `import` - Multi-collection import from structured JSON
  * `export` - Export Firestore data to JSON
* Support for multiple authentication methods:
  * Firestore Emulator (for testing)
  * Service Account (for automation)
  * OAuth2 User Consent (for CLI usage)
  * Application Default Credentials
* Comprehensive validation:
  * JSON schema validation
  * Firestore path validation
  * File size limits (100 MB max)
  * Reserved pattern detection
* Safety features:
  * Dry-run mode by default (requires --apply to execute)
  * Clear operation summaries
  * Detailed error reporting
* Configuration flexibility:
  * Three-level priority: CLI flags > .env file > system environment
  * Auto-discovery of .env files
* Designed for both AI agents and human operators:
  * Deterministic behavior
  * No interactive prompts
  * Clear exit codes (0, 1, 2, 64)
  * JSON I/O for easy integration
