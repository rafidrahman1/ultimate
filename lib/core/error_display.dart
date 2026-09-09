import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Turns a raw caught error into a short message safe to show a user,
/// stripping Dart's technical wrapper text (`Exception: `, stack-trace
/// noise, etc.) while keeping the underlying reason readable.
String humanizeError(Object error) {
  if (error is TimeoutException) {
    return 'The request timed out. Check your connection and try again.';
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
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
