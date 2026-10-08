import 'dart:io';

import '../../model/minecraft_content_models.dart';
import '../minecraft_content_file_integrity.dart';

class MtnMinecraftContentDownloadIntegrityException implements Exception {
  const MtnMinecraftContentDownloadIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'MtnMinecraftContentDownloadIntegrityException: $message';
}

class MtnMinecraftContentDownloadIntegrityRemVibe {
  MtnMinecraftContentDownloadIntegrityRemVibe._(this._integrity);

  static MtnMinecraftContentDownloadIntegrityRemVibe? fromFile(
    MtnMinecraftContentFile file,
  ) {
    final integrity = MtnMinecraftContentFileIntegrity.fromFile(file);
    if (integrity == null) {
      return null;
    }
    return MtnMinecraftContentDownloadIntegrityRemVibe._(integrity);
  }

  final MtnMinecraftContentFileIntegrity _integrity;

  int? get expectedSize => _integrity.expectedSize;
  Map<String, String> get checksums => _integrity.checksums;

  Future<void> validate(File file) async {
    try {
      await _integrity.validate(
        file,
        subject: 'Downloaded staging file',
      );
    } on MtnMinecraftContentFileIntegrityException catch (error) {
      throw MtnMinecraftContentDownloadIntegrityException(error.message);
    }
  }
}
