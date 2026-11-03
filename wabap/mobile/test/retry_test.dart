import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabap/utils/retry.dart';

void main() {
  group('isRetryableError', () {
    test('timeouts and network errors are retryable', () {
      expect(isRetryableError(TimeoutException('slow')), isTrue);
      expect(isRetryableError(const NetworkException('offline')), isTrue);
    });

    test('auth errors are NOT retryable', () {
      expect(isRetryableError(const AuthNotAuthorizedException('nope')), isFalse);
      expect(isRetryableError(const SessionExpiredException('expired')), isFalse);
    });

    test('GraphQL unauthorized/validation messages are NOT retryable', () {
      expect(isRetryableError(Exception('Unauthorized on field colis')), isFalse);
      expect(isRetryableError(Exception('Validation error of type FieldUndefined')), isFalse);
    });

    test('unknown errors default to retryable', () {
      expect(isRetryableError(Exception('socket closed')), isTrue);
    });
  });

  group('retryWithBackoff', () {
    test('retries transient failures then succeeds', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        if (attempts < 3) throw TimeoutException('flaky');
        return 'ok';
      }, baseDelay: const Duration(milliseconds: 1));
      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('rethrows after maxAttempts', () async {
      var attempts = 0;
      await expectLater(
        retryWithBackoff(() async {
          attempts++;
          throw TimeoutException('always down');
        }, maxAttempts: 3, baseDelay: const Duration(milliseconds: 1)),
        throwsA(isA<TimeoutException>()),
      );
      expect(attempts, 3);
    });

    test('does not retry when retryIf says the error is fatal', () async {
      var attempts = 0;
      await expectLater(
        retryWithBackoff(() async {
          attempts++;
          throw const AuthNotAuthorizedException('expired');
        }, retryIf: isRetryableError, baseDelay: const Duration(milliseconds: 1)),
        throwsA(isA<AuthNotAuthorizedException>()),
      );
      expect(attempts, 1);
    });
  });
}
