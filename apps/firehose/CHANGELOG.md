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
