import 'package:flutter_test/flutter_test.dart';

import 'package:industryhub/core/services.dart';
import 'package:industryhub/core/validators.dart';

void main() {
  group('shared validators', () {
    test('rejects empty and oversized required text', () {
      expect(validateRequiredText('   ', label: 'a business name'), isNotNull);
      expect(validateRequiredText('valid', label: 'a business name'), isNull);
      expect(
        validateRequiredText('12345', label: 'a name', maxLength: 4),
        isNotNull,
      );
    });

    test('accepts a valid email and rejects malformed email', () {
      expect(validateEmail('owner@example.com'), isNull);
      expect(validateEmail('owner@'), isNotNull);
      expect(validateEmail('owner.example.com'), isNotNull);
    });

    test('requires a strong password', () {
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword('onlyletters'), isNotNull);
      expect(validatePassword('StrongPass123'), isNull);
    });

    test(
      'describes AI provider errors without exposing oversized diagnostics',
      () {
        expect(
          describeAiError(
            Exception(
              'AI provider returned HTTP 404. Model: openai/gpt-oss-20b',
            ),
          ),
          contains('AI provider returned HTTP 404.'),
        );
        expect(describeAiError(''), isNotEmpty);
        expect(describeAiError('x' * 500), hasLength(321));
      },
    );

    test('validates positive and non-negative numbers', () {
      expect(validatePositiveNumber('12.5', label: 'quantity'), isNull);
      expect(validatePositiveNumber('0', label: 'quantity'), isNotNull);
      expect(
        validatePositiveNumber('not-a-number', label: 'quantity'),
        isNotNull,
      );
      expect(validateNonNegativeNumber('', label: 'price'), isNull);
      expect(validateNonNegativeNumber('0', label: 'price'), isNull);
      expect(validateNonNegativeNumber('-1', label: 'price'), isNotNull);
    });
  });
}
