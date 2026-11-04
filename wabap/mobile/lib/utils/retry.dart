import 'dart:async';
import 'dart:math';

import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:wabap/backend/backend.dart';

/// Default [retryIf] predicate: retry network-shaped errors, but never retry
/// auth or validation errors - those fail identically on every attempt and
/// retrying them just wastes the burst window.
bool isRetryableError(Object error) {
  if (error is TimeoutException) return true;
  if (error is SocketException || error is ClientException) return true;
  // Real auth failures (expired session, not authorized...) are not fixed by
  // retrying; the user has to sign in again.
  if (error is AuthException) return error.failure == AuthFailure.network;
  if (error is ApiException) {
    if (error.isUnauthorized || error.errorType == 'Unauthorized' || error.errorType == 'ValidationError') return false;
    // Erreurs serveur (5xx) ou de réseau : nouvelle tentative
    return error.statusCode == null || error.statusCode! >= 500;
  }
  final message = error.toString().toLowerCase();
  if (message.contains('unauthorized') ||
      message.contains('not authorized') ||
      message.contains('validation')) {
    return false;
  }
  return true;
}

/// Retries [action] with exponential backoff and jitter.
///
/// This replaces the old `retryOnce` (which retried instantly, so both attempts
/// died inside the same network outage). Defaults: 3 attempts, ~0.5s / 1.5s / 4s
/// base delays plus random jitter.
///
/// [retryIf] lets the caller skip retries on non-retryable errors (auth /
/// validation). By default every error is retried.
Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  Duration maxDelay = const Duration(seconds: 8),
  bool Function(Object error)? retryIf,
}) async {
  final random = Random();
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (error) {
      final canRetry = attempt < maxAttempts && (retryIf?.call(error) ?? true);
      if (!canRetry) rethrow;

      // Exponential backoff: base * 3^(attempt-1), capped, plus up to 50% jitter.
      final expMs = baseDelay.inMilliseconds * pow(3, attempt - 1);
      final cappedMs = min(expMs.toDouble(), maxDelay.inMilliseconds.toDouble());
      final jitterMs = random.nextInt((cappedMs ~/ 2) + 1);
      final delay = Duration(milliseconds: cappedMs.toInt() + jitterMs);

      safePrint('retryWithBackoff: attempt $attempt failed ($error), retrying in ${delay.inMilliseconds}ms');
      await Future.delayed(delay);
    }
  }
}
