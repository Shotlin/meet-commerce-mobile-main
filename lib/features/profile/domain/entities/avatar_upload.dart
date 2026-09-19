import 'dart:typed_data';

/// Platform-neutral avatar data for the existing multipart upload endpoint.
/// Native pickers may provide bytes from a file; browser pickers provide the
/// same bytes directly. The repository never needs a `dart:io File`.
class AvatarUpload {
  const AvatarUpload({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}
