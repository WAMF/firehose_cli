# Firehose CLI

A command-line tool for reading and writing Firestore data with JSON I/O. Designed to be non-interactive, deterministic, and safe by default with dry-run mode.

**Perfect for AI agents and automation:** Deterministic behavior, JSON I/O, no interactive prompts, clear exit codes.

## Installation

### As a Dart package (recommended)

```bash
dart pub global activate firehose_cli
```

### From source

```bash
git clone https://github.com/WAMF/firehose_cli.git
cd firehose_cli/apps/firehose
dart pub get
dart compile exe bin/firehose.dart -o firehose
```

## Configuration

Authentication can be configured via environment variables or command-line flags. Command-line flags take precedence over environment variables.

### Authentication Methods

#### Option 1: Service Account (recommended for automation & AI agents)

**Best for:** CI/CD pipelines, scripts, AI agents, server-side automation

Service accounts provide non-interactive authentication, making them ideal for automated workflows.

```bash
# Via environment variable
export FIREHOSE_PROJECT_ID="your-project-id"
export FIREHOSE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Or via command-line flag with file path
firehose --project-id your-project-id --service-account service-account.json <command>
```

**Setup:**
1. Go to [Google Cloud Console](https://console.cloud.google.com) → IAM & Admin → Service Accounts
2. Create a service account with Firestore permissions (Cloud Datastore User or Owner)
3. Create and download a JSON key
4. Use the JSON file path or inline JSON in the environment variable

#### Option 2: OAuth2 User Consent (interactive CLI usage)

**Best for:** Individual developers running commands manually

**Note:** This method requires browser interaction to grant permissions. It is **NOT suitable for AI agents or automation** as it requires human interaction.

```bash
# Via environment variables
export FIREHOSE_PROJECT_ID="your-project-id"
export FIREHOSE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export FIREHOSE_CLIENT_SECRET="your-client-secret"

# Or via command-line flags
firehose --project-id your-project-id --client-id your-client-id --client-secret your-secret <command>
```

**Setup:**
1. Go to [Google Cloud Console](https://console.cloud.google.com) → APIs & Credentials
2. Create OAuth 2.0 Client ID → Desktop application
3. Download credentials and extract `client_id` and `client_secret`
4. On first use, you'll be prompted to visit a URL and grant permissions in your browser

**Authentication flow:**
- First command prompts you to visit an authorization URL
- You log in with your Google account and grant Firestore access
- Subsequent commands use cached credentials (until they expire)

#### Option 3: Application Default Credentials (local development)

**Best for:** Developers with gcloud CLI configured

Uses credentials from `gcloud auth application-default login`. No additional configuration needed.

```bash
# Via environment variable
export FIREHOSE_PROJECT_ID="your-project-id"

# Or via command-line flag
firehose --project-id your-project-id <command>
```

**Setup:**
```bash
gcloud auth application-default login
```

#### Option 4: Firestore Emulator (testing)

**Best for:** Testing without hitting production Firestore

```bash
# Start the emulator first
firebase emulators:start --only firestore

# Then use firehose
export FIREHOSE_PROJECT_ID="test-project"
export FIRESTORE_EMULATOR_HOST="localhost:8080"

# Or via command-line flags
firehose --project-id test-project --emulator-host localhost:8080 <command>
```

**Emulator Authentication Modes:**

By default, firehose uses `Bearer owner` to bypass security rules (ideal for seeding data):

```bash
# Default: bypasses security rules
firehose --emulator-host localhost:8080 single --path users/user1 --file user.json --apply
```

To test with security rules enabled:

```bash
# Test with a custom auth token
firehose --emulator-auth-token "your-custom-token" single --path users/user1 --file user.json --apply

# Test unauthenticated access (will be blocked by rules requiring auth)
firehose --emulator-no-auth single --path users/user1 --file user.json --apply
```

Environment variables:
- `FIREHOSE_EMULATOR_AUTH_TOKEN` - Custom authentication token
- `FIREHOSE_EMULATOR_NO_AUTH=true` - Disable authentication

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

## AI Agent Usage

This tool is specifically designed to work well with AI agents and automation:

### Key Features for AI Agents

1. **Non-interactive**: All operations can be configured via flags and environment variables
2. **Deterministic**: Same input always produces same output
3. **JSON I/O**: Native JSON format for easy integration
4. **Dry-run by default**: Safe exploration without side effects
5. **Clear exit codes**: 0 (success), 1 (operation failed), 2 (config error), 64 (usage error)
6. **Structured output**: Parseable summaries and error messages

### Recommended Authentication for AI Agents

**Use Service Account authentication** (Option 1 in Configuration section above):

```bash
# Set environment variables
export FIREHOSE_PROJECT_ID="your-project-id"
export FIREHOSE_SERVICE_ACCOUNT="$(cat service-account.json)"

# Or use file path
firehose --project-id your-project-id --service-account service-account.json <command>
```

**Do NOT use OAuth2 User Consent** (Option 2) - it requires browser interaction and is not suitable for automation.

### Example AI Agent Workflow

```bash
# 1. Prepare JSON data programmatically
echo '{"name": "John Doe", "email": "john@example.com"}' > user.json

# 2. Preview the operation (dry-run)
firehose single --path users/user123 --file user.json --verbose

# 3. If valid, apply the operation
firehose single --path users/user123 --file user.json --apply

# 4. Check exit code
if [ $? -eq 0 ]; then
  echo "Success"
else
  echo "Failed"
fi
```

### Configuration Priority

When multiple configuration sources are present:
1. **CLI flags** (highest priority)
2. **.env file** (auto-discovered in current and parent directories)
3. **System environment variables** (lowest priority)

This allows AI agents to override default configurations easily.