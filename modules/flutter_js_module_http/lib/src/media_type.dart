/// A regular expression matching a character that needs to be backslash-escaped
/// in a quoted string.
final _escapedChar = RegExp(r'["\x00-\x1F\x7F]');
final _nonToken = RegExp(r'[()<>@,;:"\\/\[\]?={} \t\x00-\x1F\x7F]');

/// A class representing an HTTP media type, as used in Accept and Content-Type
/// headers.
class MediaType {
  /// The primary identifier of the MIME type.
  ///
  /// This is always lowercase.
  final String type;

  /// The secondary identifier of the MIME type.
  ///
  /// This is always lowercase.
  final String subtype;

  /// The parameters to the media type.
  ///
  /// This map is immutable and the keys are case-insensitive.
  final Map<String, String> parameters;

  /// The media type's MIME type.
  String get mimeType => '$type/$subtype';

  factory MediaType.parse(String mediaType) {
    int slash = mediaType.indexOf('/');
    final type = mediaType.substring(0, slash).trim().toLowerCase();
    int comma = mediaType.indexOf(';');
    final subtype;
    final parameters = <String, String>{};
    if (comma == -1) {
      subtype = mediaType.substring(slash + 1).trim();
    } else {
      subtype = mediaType.substring(slash + 1, comma).trim();
      mediaType.substring(comma + 1).split(';').forEach((p) {
        int pos = p.indexOf('=');
        if (pos == -1) {
          return;
        }
        parameters[p.substring(0, pos).trim().toLowerCase()] =
            p.substring(pos + 1).trim().toLowerCase();
      });
    }
    return MediaType._(type, subtype, parameters);
  }

  MediaType._(this.type, this.subtype, this.parameters);

  /// Converts the media type to a string.
  ///
  /// This will produce a valid HTTP media type.
  @override
  String toString() {
    final buffer = StringBuffer()..write(type)..write('/')..write(subtype);

    parameters.forEach((attribute, value) {
      buffer.write('; $attribute=');
      if (_nonToken.hasMatch(value)) {
        buffer
          ..write('"')
          ..write(
              value.replaceAllMapped(_escapedChar, (match) => '\\${match[0]}'))
          ..write('"');
      } else {
        buffer.write(value);
      }
    });

    return buffer.toString();
  }
}
