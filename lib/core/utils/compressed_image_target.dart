/// Where a picked photo's compressed copy is written, and in which format.
///
/// The copy is a PNG only when the source is one; everything else (JPEG,
/// HEIC, WebP) is re-encoded as JPEG, so the target carries `.jpg` and the
/// name always matches the bytes. The extension is matched case-insensitively
/// and only at the end of the path, so `IMG_1.JPG` gets its own target file
/// rather than one equal to the source, which the compressor refuses.
({String path, bool isPng}) compressedImageTarget(String sourcePath) {
  final slash = sourcePath.lastIndexOf('/');
  final dot = sourcePath.lastIndexOf('.');
  final hasExtension = dot > slash + 1;

  final base = hasExtension ? sourcePath.substring(0, dot) : sourcePath;
  final isPng =
      hasExtension && sourcePath.substring(dot + 1).toLowerCase() == 'png';

  return (path: '${base}_compressed.${isPng ? 'png' : 'jpg'}', isPng: isPng);
}
