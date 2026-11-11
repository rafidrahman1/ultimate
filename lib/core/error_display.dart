import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Turns a raw caught error into a short message safe to show a user,
/// stripping Dart's technical wrapper text (`Exception: `, stack-trace
/// noise, etc.) while keeping the underlying reason readable.
String humanizeError(Object error) {
  // A provider that fails because one it depends on failed reports the
  // original error inside a wrapper; show the original.
  if (error is ProviderException) return humanizeError(error.exception);
  if (error is TimeoutException) {
    return 'The request timed out. Check your connection and try again.';
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google sign-in was canceled or could not verify your account. '
            'Try again, or re-add the account in Android settings.',
      _ =>
        error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Google sign-in failed (${error.code.name}).',
    };
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    return message != null && message.isNotEmpty
        ? message
        : 'Something went wrong (${error.code}).';
  }
  if (error is FormatException) {
    return 'The data could not be read (invalid format).';
  }

  var message = error.toString().trim();
  const wrapperPrefixes = [
    'Exception: ',
    'FormatException: ',
    'StateError: ',
    'ArgumentError: ',
  ];
  for (final prefix in wrapperPrefixes) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length).trim();
      break;
    }
  }
  return message.isEmpty ? 'Something went wrong.' : message;
}
