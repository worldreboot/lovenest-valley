import 'package:flutter/foundation.dart';
import 'dart:collection';

/// Service to collect and store debug logs for in-app display
/// Useful for TestFlight builds where console logs aren't easily accessible
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 200; // Keep last 200 logs
  String? _lastError;
  DateTime? _lastErrorTime;
  
  final List<VoidCallback> _listeners = [];

  /// Get all logs
  List<LogEntry> get logs => List.unmodifiable(_logs);
  
  /// Get last error
  String? get lastError => _lastError;
  DateTime? get lastErrorTime => _lastErrorTime;
  
  /// Get recent logs (last N entries)
  List<LogEntry> getRecentLogs({int count = 50}) {
    if (_logs.length <= count) return List.unmodifiable(_logs);
    return List.unmodifiable(_logs.sublist(_logs.length - count));
  }

  /// Add a log entry
  void addLog(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );
    
    _logs.add(entry);
    
    // Keep only last _maxLogs entries
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // Track errors
    if (level == LogLevel.error) {
      _lastError = message;
      _lastErrorTime = entry.timestamp;
    }
    
    // Also print to console for development
    debugPrint('[${entry.timestamp.toString().substring(11, 19)}] $message');
    
    // Notify listeners
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Add an error log
  void addError(String message, [dynamic error, StackTrace? stackTrace]) {
    String fullMessage = message;
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStack: ${stackTrace.toString().split('\n').take(5).join('\n')}';
    }
    addLog(fullMessage, level: LogLevel.error);
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    _lastError = null;
    _lastErrorTime = null;
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Add a listener for log updates
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

enum LogLevel {
  info,
  warning,
  error,
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  String get levelString {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

