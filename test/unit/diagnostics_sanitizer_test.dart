import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';

void main() {
  group('DiagnosticSanitizer', () {
    test('redacts blacklisted sensitive keys in flat map', () {
      final input = {
        'username': 'admin_pos',
        'password': 'SuperSecretPassword123!',
        'user_pin': '1234',
        'pinhash': 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3',
        'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
        'refresh_token': 'refresh_xyz_987',
        'api_secret': 'sk_test_51MzZ',
        'authorization': 'Bearer confidential_token',
        'creditCard': '4111222233334444',
        'cvv': '123',
        'salt': 'random_salt_123',
      };

      final sanitized = DiagnosticSanitizer.sanitizeMap(input);

      expect(sanitized['username'], equals('admin_pos'));
      expect(sanitized['password'], equals('[REDACTED]'));
      expect(sanitized['user_pin'], equals('[REDACTED]'));
      expect(sanitized['pinhash'], equals('[REDACTED]'));
      expect(sanitized['access_token'], equals('[REDACTED]'));
      expect(sanitized['refresh_token'], equals('[REDACTED]'));
      expect(sanitized['api_secret'], equals('[REDACTED]'));
      expect(sanitized['authorization'], equals('[REDACTED]'));
      expect(sanitized['creditCard'], equals('[REDACTED]'));
      expect(sanitized['cvv'], equals('[REDACTED]'));
      expect(sanitized['salt'], equals('[REDACTED]'));
    });

    test('recursively redacts nested maps and lists', () {
      final input = {
        'storeId': 'store_delhi_01',
        'authPayload': {
          'session': 'sess_1',
          'secret': 'nested_secret_xyz',
          'headers': ['Bearer abcd1234xyz', 'safe_string'],
        },
        'employees': [
          {'name': 'Raj', 'pin': '9999'},
          {'name': 'Anita', 'password': 'mypassword'},
        ],
      };

      final sanitized = DiagnosticSanitizer.sanitizeMap(input);

      expect(sanitized['storeId'], equals('store_delhi_01'));
      final auth = sanitized['authPayload'] as Map<String, dynamic>;
      expect(auth['session'], equals('sess_1'));
      expect(auth['secret'], equals('[REDACTED]'));
      final headers = auth['headers'] as List;
      expect(headers[0], contains('[REDACTED]'));
      expect(headers[1], equals('safe_string'));

      final employees = sanitized['employees'] as List;
      expect(employees[0]['pin'], equals('[REDACTED]'));
      expect(employees[0]['name'], equals('Raj'));
      expect(employees[1]['password'], equals('[REDACTED]'));
      expect(employees[1]['name'], equals('Anita'));
    });

    test('masks email addresses and phone numbers', () {
      final input = {
        'customer_email': 'contact@example.com',
        'short_email': 'ab@pos.com',
        'customer_phone': '+91 9876543210',
        'customer_mobile': '9876543210',
      };

      final sanitized = DiagnosticSanitizer.sanitizeMap(input);

      expect(sanitized['customer_email'], equals('co***@example.com'));
      expect(sanitized['short_email'], equals('a***@pos.com'));
      expect(sanitized['customer_phone'], contains('***'));
      expect(sanitized['customer_phone'], endsWith('10'));
      expect(sanitized['customer_mobile'], contains('***'));
      expect(sanitized['customer_mobile'], endsWith('10'));
    });

    test('sanitizes bearer and offline hash strings from text', () {
      const textWithBearer = 'Error calling endpoint: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final cleanedBearer = DiagnosticSanitizer.sanitizeString(textWithBearer);
      expect(cleanedBearer, equals('Error calling endpoint: Bearer [REDACTED]'));

      const textWithHash = 'Failed matching offline_hash_987654321abc for user';
      final cleanedHash = DiagnosticSanitizer.sanitizeString(textWithHash);
      expect(cleanedHash, equals('Failed matching offline_hash_[REDACTED] for user'));
    });
  });
}
