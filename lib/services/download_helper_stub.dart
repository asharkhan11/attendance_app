import 'dart:typed_data';

/// Stub for non-web platforms — file download is a no-op
/// (on Android you'd use path_provider + File.writeAsBytes instead)
void triggerDownload(Uint8List bytes, String filename, String mimeType) {
  // No-op on non-web platforms.
  // For Android, integrate path_provider to save to Downloads.
}
