# Firehose CLI

A command-line tool for reading and writing Firestore data with JSON I/O. Designed to be non-interactive, deterministic, and safe by default with dry-run mode.

## Installation

### As a Dart package (recommended)

```bash
dart pub global activate firehose
```

### From source

```bash
git clone https://github.com/yourusername/firehose_cli.git
cd firehose_cli/apps/firehose
dart pub get
dart compile exe bin/firehose.dart -o firehose
```

## Configuration

Authentication can be configured via environment variables or command-line flags. Command-line flags take precedence over environment variables.

### Authentication Methods

#### Option 1: Firestore Emulator (for testing)
```bash
# Via environment variables
export FIREHOSE_PROJECT_ID="test-project"
export FIRESTORE_EMULATOR_HOST="localhost:8080"

# Or via command-line flags
firehose --project-id test-project --emulator-host localhost:8080 <command>
```

#### Option 2: Service Account (recommended for automation)
```bash
# Via environment variable
export FIREHOSE_PROJECT_ID="your-project-id"
export FIREHOSE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Or via command-line flag with file path
firehose --project-id your-project-id --service-account service-account.json <command>
```

#### Option 3: OAuth2 User Consent (for CLI usage)
```bash
# Via environment variables
export FIREHOSE_PROJECT_ID="your-project-id"
export FIREHOSE_CLIENT_ID="your-client-id"
export FIREHOSE_CLIENT_SECRET="your-client-secret"

# Or via command-line flags
firehose --project-id your-project-id --client-id your-client-id --client-secret your-secret <command>
```

#### Option 4: Application Default Credentials
```bash
# Via environment variable
export FIREHOSE_PROJECT_ID="your-project-id"

# Or via command-line flag
firehose --project-id your-project-id --use-adc <command>
```

## Commands

### single - Write one document from a JSON file

```bash
# Dry run (default)
firehose single --path users/user123 --file data.json

# Apply changes
firehose single --path users/user123 --file data.json --apply

# Use field as document ID
firehose single --path users --file data.json --id-field userId --apply

# Merge instead of replace
firehose single --path users/user123 --file data.json --merge --apply
```

### batch - Write many documents to one collection

```bash
# Dry run with ID field
firehose batch --collection users --file users.json --id-field id

# Apply with auto-generated IDs for missing ID fields
firehose batch --collection users --file users.json --id-field userId --apply

# Merge existing documents
firehose batch --collection users --file users.json --id-field id --merge --apply
```

### import - Multi-collection import from JSON map

```bash
# Import multiple collections
firehose import --file collections.json

# Apply changes
firehose import --file collections.json --apply

# Merge mode
firehose import --file collections.json --merge --apply
```

Expected file format:
```json
{
  "collection/path": {
    "id field name": "fieldName",
    "data": [
      { "fieldName": "doc1", ... },
      { "fieldName": "doc2", ... }
    ]
  }
}
```

### export - Export Firestore data to JSON

```bash
# Export a collection
firehose export --path users --output users_backup.json

# Export with limit
firehose export --path users --output users.json --limit 100

# Export a single document
firehose export --path users/user123 --output user.json
```

## Global Options

### Authentication Flags
- `--project-id`: Google Cloud project ID (overrides FIREHOSE_PROJECT_ID)
- `--emulator-host`: Firestore emulator host (e.g., localhost:8080)
- `--service-account`: Path to service account JSON file
- `--client-id`: OAuth2 client ID for user consent flow
- `--client-secret`: OAuth2 client secret for user consent flow
- `--use-adc`: Use Application Default Credentials

### Command Flags
- `--apply`: Execute the operation (without this, runs in dry-run mode)
- `--verbose` / `-v`: Show detailed output
- `--merge`: Merge with existing documents instead of replacing
- `--version` / `-v`: Show version information

## Exit Codes

- 0: Success
- 1: Operation failed with errors
- 2: Invalid arguments or configuration error
- 64: Usage error

## Examples

### Example: Import test data
```bash
# Review the import plan
firehose import --file test_data/import_collections.json --verbose

# Apply the import
firehose import --file test_data/import_collections.json --apply
```

### Example: Backup and restore
```bash
# Backup users collection
firehose export --path users --output backup/users.json

# Restore from backup
firehose batch --collection users --file backup/users.json --id-field id --apply
```

### Example: Single document with validation
```bash
# First check what will be written
firehose single --path config/app --file config.json --verbose

# If looks good, apply
firehose single --path config/app --file config.json --apply
```

## Safety Features

1. **Dry-run by default**: Operations are not executed unless `--apply` is specified
2. **Clear summaries**: Shows exactly what will be done before execution
3. **Validation**: Strict JSON shape validation and Firestore path validation
4. **Detailed reporting**: Summary of created/updated/skipped/failed operations
5. **Error handling**: Proper exit codes and error messages

## Test Data

Example JSON files are provided in `test_data/`:
- `single_document.json`: Single document example
- `batch_documents.json`: Array of documents with some having IDs
- `import_collections.json`: Multi-collection import structure