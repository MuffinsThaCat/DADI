/// A generic class to represent the result of an operation
/// Contains success status, optional data, and optional error message
class OperationResult<T> {
  final bool success;
  final T? data;
  final String message;

  OperationResult({
    required this.success,
    this.data,
    this.message = '',
  });

  /// Create a successful result with data
  factory OperationResult.success({T? data, String message = 'Operation completed successfully'}) {
    return OperationResult<T>(
      success: true,
      data: data,
      message: message,
    );
  }

  /// Create a failed result with error message
  factory OperationResult.failure({String message = 'Operation failed', T? data}) {
    return OperationResult<T>(
      success: false,
      data: data,
      message: message,
    );
  }

  @override
  String toString() {
    return 'OperationResult{success: $success, message: $message, data: $data}';
  }
}
