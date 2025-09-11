/// Tracks the result of operations for reporting
class OperationResult {
  /// Number of documents created.
  int created = 0;

  /// Number of documents updated.
  int updated = 0;

  /// Number of documents skipped.
  int skipped = 0;

  /// Number of operations that failed.
  int failed = 0;

  /// Number of auto-generated IDs.
  int autoId = 0;

  /// Number of documents read.
  int read = 0;

  /// Number of bytes written to output.
  int bytesWritten = 0;

  /// List of error messages.
  final List<String> errors = [];

  /// List of operation details.
  final List<OperationDetail> details = [];

  /// Adds a created document to the result.
  void addCreated(String path, {bool autoId = false}) {
    created++;
    if (autoId) this.autoId++;
    details.add(
      OperationDetail(
        type: OperationType.created,
        path: path,
        autoId: autoId,
      ),
    );
  }

  /// Adds an updated document to the result.
  void addUpdated(String path) {
    updated++;
    details.add(
      OperationDetail(
        type: OperationType.updated,
        path: path,
      ),
    );
  }

  /// Adds a skipped document to the result.
  void addSkipped(String path, String reason) {
    skipped++;
    details.add(
      OperationDetail(
        type: OperationType.skipped,
        path: path,
        message: reason,
      ),
    );
  }

  /// Adds a failed operation to the result.
  void addFailed(String path, String error) {
    failed++;
    errors.add('$path: $error');
    details.add(
      OperationDetail(
        type: OperationType.failed,
        path: path,
        message: error,
      ),
    );
  }

  /// Adds a read document to the result.
  void addRead(String path) {
    read++;
    details.add(
      OperationDetail(
        type: OperationType.read,
        path: path,
      ),
    );
  }

  /// Gets the total number of operations.
  int get total => created + updated + skipped + failed;

  /// Whether any operations failed.
  bool get hasErrors => failed > 0;

  /// Whether all operations succeeded.
  bool get isSuccess => failed == 0;

  /// Gets a summary of the operations.
  String get summary {
    final parts = <String>[];

    if (created > 0) {
      parts.add('Created: $created${autoId > 0 ? ' ($autoId auto-ID)' : ''}');
    }
    if (updated > 0) parts.add('Updated: $updated');
    if (skipped > 0) parts.add('Skipped: $skipped');
    if (failed > 0) parts.add('Failed: $failed');
    if (read > 0) parts.add('Read: $read');
    if (bytesWritten > 0) {
      parts.add('Bytes written: $bytesWritten');
    }

    if (parts.isEmpty) {
      return 'No operations performed';
    }

    return parts.join(', ');
  }

  /// Prints a summary of the operations.
  void printSummary({bool verbose = false}) {
    print('\n=== Operation Summary ===');
    print(summary);

    if (errors.isNotEmpty) {
      print('\nErrors:');
      for (final error in errors) {
        print('  ✗ $error');
      }
    }

    if (verbose && details.isNotEmpty) {
      print('\nDetails:');
      for (final detail in details) {
        print(
          '  ${detail.icon} ${detail.path}${detail.message != null ? ': ${detail.message}' : ''}',
        );
      }
    }
  }
}

/// Represents a single operation detail
class OperationDetail {
  /// Creates an operation detail.
  OperationDetail({
    required this.type,
    required this.path,
    this.message,
    this.autoId = false,
  });

  /// The type of operation.
  final OperationType type;

  /// The path of the document.
  final String path;

  /// Optional message for the operation.
  final String? message;

  /// Whether an auto-ID was used.
  final bool autoId;

  /// Gets the icon for this operation type.
  String get icon {
    switch (type) {
      case OperationType.created:
        return autoId ? '⚡' : '✓';
      case OperationType.updated:
        return '↻';
      case OperationType.skipped:
        return '⊘';
      case OperationType.failed:
        return '✗';
      case OperationType.read:
        return '📖';
    }
  }
}

/// Types of operations
enum OperationType {
  /// Document was created.
  created,

  /// Document was updated.
  updated,

  /// Document was skipped.
  skipped,

  /// Operation failed.
  failed,

  /// Document was read.
  read,
}
