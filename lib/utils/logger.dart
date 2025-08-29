import 'dart:developer' as developer;

/// Simple logging utility for the Harmony Music app
class Logger {
  static const String _appName = 'HarmonyMusic';

  /// Log an info message
  static void info(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _appName,
      level: 800, // Info level
    );
  }

  /// Log an error message
  static void error(String message,
      [String? tag, Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: tag ?? _appName,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  static void warning(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _appName,
      level: 900, // Warning level
    );
  }

  /// Log a debug message
  static void debug(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _appName,
      level: 700, // Debug level
    );
  }
}
