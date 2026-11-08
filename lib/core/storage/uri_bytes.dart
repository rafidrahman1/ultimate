import 'dart:typed_data';

import 'package:uri_content/uri_content.dart';

/// Reads a whole URI (file or Android content://) into memory.
///
/// `UriContent.from` joins chunks with `[...previous, ...chunk]`, which boxes
/// every byte and recopies the accumulated data per chunk on the UI thread:
/// a 40 MB file stalled the app for seconds. Appending to a [BytesBuilder]
/// without copying keeps it to a single final copy.
Future<Uint8List> readUriBytes(UriContent reader, Uri uri) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in reader.getContentStream(uri)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
