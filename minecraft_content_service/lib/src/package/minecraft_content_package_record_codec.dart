import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'minecraft_content_package_record.dart';

/// Encrypted local record wire format, version 1:
/// UTF8 magic (MTNCR), 1-byte format version, 1-byte key-id length,
/// UTF8 key-id, AES-GCM 12-byte random nonce, ciphertext and 16-byte tag.
///
/// The entire unencrypted header is authenticated as AES-GCM AAD. The key
/// itself is **never embedded**, derived or fetched by this library.
class MtnMinecraftContentPackageRecordCodec {
  MtnMinecraftContentPackageRecordCodec() : _algorithm = AesGcm.with256bits();

  static const int formatVersion = 1;
  static const int keyLength = 32;
  static const List<int> _magic = <int>[77, 84, 78, 67, 82]; // MTNCR
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  final AesGcm _algorithm;

  Future<Uint8List> encrypt(
    MtnMinecraftContentPackageRecord record, {
    required Uint8List key,
    required String keyId,
  }) async {
    _requireKey(key);
    final idBytes = utf8.encode(keyId);
    if (keyId.trim() != keyId || idBytes.isEmpty || idBytes.length > 255) {
      throw ArgumentError.value(keyId, 'keyId', 'Key ID must be nonempty, trimmed UTF-8 up to 255 bytes.');
    }
    final header = <int>[..._magic, formatVersion, idBytes.length, ...idBytes];
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(record.toMap())),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: header,
    );
    return Uint8List.fromList(<int>[...header, ...box.concatenation()]);
  }

  /// Caller can select the correct externally provided key by reading keyId.
  /// This field is authenticated only after decrypt() completes successfully.
  String readKeyId(Uint8List data) => _header(data).$1;

  Future<MtnMinecraftContentPackageRecord> decrypt(
    Uint8List data, {
    required Uint8List key,
    String? expectedKeyId,
  }) async {
    _requireKey(key);
    final (keyId, headerEnd) = _header(data);
    if (expectedKeyId != null && keyId != expectedKeyId) {
      throw FormatException('Encrypted record key ID does not match the requested key ID.');
    }
    final header = data.sublist(0, headerEnd);
    final box = SecretBox.fromConcatenation(
      data.sublist(headerEnd),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    final bytes = await _algorithm.decrypt(box, secretKey: SecretKey(key), aad: header);
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map) throw const FormatException('Decrypted Content Package Record is not a JSON object.');
    return MtnMinecraftContentPackageRecord.fromMap(Map<String, dynamic>.from(value));
  }

  (String, int) _header(Uint8List data) {
    if (data.length < _magic.length + 2 + _nonceLength + _macLength) throw const FormatException('Encrypted record header is too short.');
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) throw const FormatException('Unknown encrypted record magic.');
    }
    if (data[_magic.length] != formatVersion) throw const FormatException('Unsupported encrypted record version.');
    final idLength = data[_magic.length + 1];
    final end = _magic.length + 2 + idLength;
    if (idLength == 0 || data.length < end + _nonceLength + _macLength) throw const FormatException('Invalid encrypted record key ID or payload length.');
    final id = utf8.decode(data.sublist(_magic.length + 2, end));
    if (id.isEmpty || id.trim() != id) throw const FormatException('Invalid encrypted record key ID.');
    return (id, end);
  }

  void _requireKey(Uint8List key) {
    if (key.length != keyLength) throw ArgumentError.value(key.length, 'key', 'AES-256-GCM key must contain exactly 32 bytes.');
  }
}
