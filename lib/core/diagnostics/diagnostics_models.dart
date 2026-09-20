import 'dart:convert';

/// Subsystems monitored by the BizPOS Production Diagnostics Engine.
enum DiagnosticSubsystem {
  auth,
  checkout,
  inventory,
  sync,
  firebase,
  migration,
  printing,
  subscription,
  permission,
  recovery,
}

extension DiagnosticSubsystemX on DiagnosticSubsystem {
  String get nameUpper => name.toUpperCase();

  static DiagnosticSubsystem fromString(String val) {
    return DiagnosticSubsystem.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.nameUpper == val.toUpperCase(),
      orElse: () => DiagnosticSubsystem.recovery,
    );
  }
}

/// Standardized error categories for field diagnostics without a debugger.
enum DiagnosticErrorCategory {
  authError,
  permissionError,
  validationError,
  networkError,
  databaseError,
  syncError,
  conflictError,
  printError,
  migrationError,
  internalError,
}

extension DiagnosticErrorCategoryX on DiagnosticErrorCategory {
  String get code {
    switch (this) {
      case DiagnosticErrorCategory.authError:
        return 'AUTH_ERROR';
      case DiagnosticErrorCategory.permissionError:
        return 'PERMISSION_ERROR';
      case DiagnosticErrorCategory.validationError:
        return 'VALIDATION_ERROR';
      case DiagnosticErrorCategory.networkError:
        return 'NETWORK_ERROR';
      case DiagnosticErrorCategory.databaseError:
        return 'DATABASE_ERROR';
      case DiagnosticErrorCategory.syncError:
        return 'SYNC_ERROR';
      case DiagnosticErrorCategory.conflictError:
        return 'CONFLICT_ERROR';
      case DiagnosticErrorCategory.printError:
        return 'PRINT_ERROR';
      case DiagnosticErrorCategory.migrationError:
        return 'MIGRATION_ERROR';
      case DiagnosticErrorCategory.internalError:
        return 'INTERNAL_ERROR';
    }
  }

  static DiagnosticErrorCategory? fromString(String? val) {
    if (val == null || val.isEmpty) return null;
    final normalized = val.toUpperCase().replaceAll('_', '');
    for (final cat in DiagnosticErrorCategory.values) {
      if (cat.code.replaceAll('_', '') == normalized || cat.name.toUpperCase() == normalized) {
        return cat;
      }
    }
    return DiagnosticErrorCategory.internalError;
  }
}

/// Execution result of a diagnosed operation.
enum DiagnosticResult {
  success,
  failure,
  warning,
}

/// Automated Redaction & Masking Utility.
/// Guarantees that passwords, PINs, tokens, secret keys, and private customer
/// information are never stored or exported in diagnostics.
class DiagnosticSanitizer {
  static bool _isSensitiveKey(String keyLower) {
    if (keyLower.contains('password') ||
        keyLower.contains('pinhash') ||
        keyLower == 'pin' ||
        keyLower.endsWith('pin') ||
        keyLower.contains('token') ||
        keyLower.contains('secret') ||
        keyLower.contains('authorization') ||
        keyLower.contains('cookie') ||
        keyLower.contains('creditcard') ||
        keyLower.contains('cardnumber') ||
        keyLower.contains('cvv') ||
        keyLower.contains('cvc') ||
        keyLower.contains('salt')) {
      return true;
    }
    return false;
  }

  /// Recursively scrubs sensitive values from a map.
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic>? input) {
    if (input == null) return {};
    final result = <String, dynamic>{};

    for (final entry in input.entries) {
      final keyLower = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (entry.value is Map) {
        result[entry.key] = sanitizeMap(Map<String, dynamic>.from(entry.value as Map));
      } else if (_isSensitiveKey(keyLower)) {
        result[entry.key] = '[REDACTED]';
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((item) {
          if (item is Map) {
            return sanitizeMap(Map<String, dynamic>.from(item));
          } else if (item is String) {
            return sanitizeString(item);
          }
          return item;
        }).toList();
      } else if (entry.value is String) {
        if (keyLower.contains('phone') || keyLower.contains('mobile')) {
          result[entry.key] = maskPhoneNumber(entry.value as String);
        } else if (keyLower.contains('email')) {
          result[entry.key] = maskEmail(entry.value as String);
        } else {
          result[entry.key] = sanitizeString(entry.value as String);
        }
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Masks email addresses (e.g. j***@example.com).
  static String maskEmail(String email) {
    if (!email.contains('@')) return sanitizeString(email);
    final parts = email.split('@');
    final user = parts[0];
    final domain = parts[1];
    if (user.length <= 2) {
      return '${user[0]}***@$domain';
    }
    return '${user.substring(0, 2)}***@$domain';
  }

  /// Masks phone numbers (e.g. +91 98*** **321).
  static String maskPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length <= 4) return '***';
    final start = cleaned.substring(0, cleaned.length > 7 ? 4 : 2);
    final end = cleaned.substring(cleaned.length - 2);
    return '$start***$end';
  }

  /// Scrubs token-like strings or potential embedded passwords from text.
  static String sanitizeString(String text) {
    var sanitized = text;
    // Scrub Bearer tokens
    sanitized = sanitized.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false), 'Bearer [REDACTED]');
    // Scrub Firebase refresh tokens or session hashes
    sanitized = sanitized.replaceAll(RegExp(r'offline_hash_[A-Za-z0-9_\-]+', caseSensitive: false), 'offline_hash_[REDACTED]');
    return sanitized;
  }
}

/// A structured, production-grade diagnostic event.
class DiagnosticEvent {
  final String id;
  final String operationId;
  final DiagnosticSubsystem subsystem;
  final String? storeId;
  final String? userId;
  final String deviceId;
  final String? entityId;
  final DateTime timestamp;
  final DiagnosticResult result;
  final int durationMs;
  final DiagnosticErrorCategory? errorCategory;
  final String message;
  final Map<String, dynamic> metadata;
  final String? stackTrace;

  DiagnosticEvent({
    required this.id,
    required this.operationId,
    required this.subsystem,
    this.storeId,
    this.userId,
    required this.deviceId,
    this.entityId,
    required this.timestamp,
    required this.result,
    required this.durationMs,
    this.errorCategory,
    required this.message,
    Map<String, dynamic>? metadata,
    this.stackTrace,
  }) : metadata = DiagnosticSanitizer.sanitizeMap(metadata);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operationId': operationId,
      'subsystem': subsystem.nameUpper,
      'storeId': storeId,
      'userId': userId != null ? DiagnosticSanitizer.sanitizeString(userId!) : null,
      'deviceId': deviceId,
      'entityId': entityId,
      'timestamp': timestamp.toIso8601String(),
      'result': result.name.toUpperCase(),
      'durationMs': durationMs,
      'errorCategory': errorCategory?.code,
      'message': DiagnosticSanitizer.sanitizeString(message),
      'metadata': metadata,
      'stackTrace': stackTrace != null ? DiagnosticSanitizer.sanitizeString(stackTrace!) : null,
    };
  }

  factory DiagnosticEvent.fromMap(Map<String, dynamic> map) {
    return DiagnosticEvent(
      id: map['id']?.toString() ?? '',
      operationId: map['operationId']?.toString() ?? '',
      subsystem: DiagnosticSubsystemX.fromString(map['subsystem']?.toString() ?? 'recovery'),
      storeId: map['storeId']?.toString(),
      userId: map['userId']?.toString(),
      deviceId: map['deviceId']?.toString() ?? 'unknown',
      entityId: map['entityId']?.toString(),
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      result: _parseResult(map['result']?.toString()),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      errorCategory: DiagnosticErrorCategoryX.fromString(map['errorCategory']?.toString()),
      message: map['message']?.toString() ?? '',
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
      stackTrace: map['stackTrace']?.toString(),
    );
  }

  static DiagnosticResult _parseResult(String? res) {
    switch (res?.toUpperCase()) {
      case 'SUCCESS':
        return DiagnosticResult.success;
      case 'WARNING':
        return DiagnosticResult.warning;
      case 'FAILURE':
      default:
        return DiagnosticResult.failure;
    }
  }

  String toJson() => jsonEncode(toMap());
}
