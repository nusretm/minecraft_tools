// Manual local validation for one real Java Edition servers.dat file.
// This tool never modifies the supplied file. It copies it to a temporary
// game directory and performs read + append + re-read validation there.
import 'dart:io';

import 'package:minecraft_info_provider/minecraft_info_provider.dart';

Future<void> main(List<String> arguments) async {
  final String sourcePath = _requiredValue(arguments, '--servers-file');
  final File source = File(sourcePath).absolute;
  if (!await source.exists()) {
    throw ArgumentError.value(
      source.path,
      '--servers-file',
      'File does not exist',
    );
  }

  final List<int> sourceBytes = await source.readAsBytes();
  final MtnMinecraftNbtDocument originalDocument =
      const MtnMinecraftNbtCodec().decode(sourceBytes);
  if (originalDocument.root.type != MtnMinecraftNbtType.compound) {
    throw StateError('servers.dat root is not TAG_Compound');
  }
  final MtnMinecraftNbtValue? originalServersValue =
      originalDocument.root.asCompound['servers'];
  if (originalServersValue == null ||
      originalServersValue.type != MtnMinecraftNbtType.list ||
      originalServersValue.asList.elementType !=
          MtnMinecraftNbtType.compound) {
    throw StateError('servers.dat does not contain a compound server list');
  }
  final List<MtnMinecraftNbtValue> originalRawServers =
      originalServersValue.asList.values;

  final Directory temp =
      await Directory.systemTemp.createTemp('mtn-info-provider-validation-');
  try {
    final File copy =
        File('${temp.path}${Platform.pathSeparator}servers.dat');
    await copy.writeAsBytes(sourceBytes, flush: true);

    final MtnMinecraftInfoProvider provider =
        MtnMinecraftInfoProvider(gameDirectory: temp);
    final List<MtnMinecraftInfoServer> before =
        await provider.readServers();

    stdout.writeln(
      'CHECKPOINT parsed=true bytes=${sourceBytes.length} '
      'servers=${before.length}',
    );
    for (var index = 0; index < before.length; index++) {
      final MtnMinecraftInfoServer server = before[index];
      stdout.writeln(
        'SERVER index=$index name=${server.name} '
        'address=${server.address} hidden=${server.hidden} '
        'icon=${server.icon != null} '
        'resourcePackPolicy=${server.acceptServerResourcePacks}',
      );
    }

    const String validationName = 'Minecraft Info Provider Validation';
    const String validationAddress = 'validation.invalid:25565';
    await provider.addServer(
      MtnMinecraftInfoServer(
        name: validationName,
        address: validationAddress,
        hidden: true,
        acceptServerResourcePacks: true,
      ),
    );

    final List<MtnMinecraftInfoServer> after =
        await provider.readServers();
    if (after.length != before.length + 1) {
      throw StateError('Appended server count is invalid');
    }
    for (var index = 0; index < before.length; index++) {
      final MtnMinecraftInfoServer left = before[index];
      final MtnMinecraftInfoServer right = after[index];
      if (left.toJson() != right.toJson()) {
        throw StateError(
          'Existing server model changed at index $index',
        );
      }
    }
    final MtnMinecraftInfoServer appended = after.last;
    if (appended.name != validationName ||
        appended.address != validationAddress ||
        !appended.hidden ||
        appended.acceptServerResourcePacks != true) {
      throw StateError('Appended server semantic values are invalid');
    }

    final MtnMinecraftNbtDocument updatedDocument =
        const MtnMinecraftNbtCodec().decode(
      await copy.readAsBytes(),
    );
    final MtnMinecraftNbtValue? updatedServersValue =
        updatedDocument.root.asCompound['servers'];
    if (updatedServersValue == null ||
        updatedServersValue.type != MtnMinecraftNbtType.list) {
      throw StateError('Updated server list is invalid');
    }
    final List<MtnMinecraftNbtValue> updatedRawServers =
        updatedServersValue.asList.values;
    if (updatedRawServers.length != originalRawServers.length + 1) {
      throw StateError('Updated raw server count is invalid');
    }
    for (var index = 0; index < originalRawServers.length; index++) {
      final List<int> originalBytes = const MtnMinecraftNbtCodec().encode(
        MtnMinecraftNbtDocument(
          name: '',
          root: originalRawServers[index],
        ),
      );
      final List<int> updatedBytes = const MtnMinecraftNbtCodec().encode(
        MtnMinecraftNbtDocument(
          name: '',
          root: updatedRawServers[index],
        ),
      );
      if (!_sameBytes(originalBytes, updatedBytes)) {
        throw StateError(
          'Existing raw NBT changed at index $index',
        );
      }
    }

    stdout.writeln(
      'CHECKPOINT append=true preservedExisting=true '
      'servers=${after.length}',
    );
    stdout.writeln('VALIDATION_RESULT PASS');
  } finally {
    await temp.delete(recursive: true);
  }
}

String _requiredValue(List<String> arguments, String name) {
  final int index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    throw ArgumentError('$name is required');
  }
  final String value = arguments[index + 1];
  if (value.trim().isEmpty) {
    throw ArgumentError('$name must not be empty');
  }
  return value;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
