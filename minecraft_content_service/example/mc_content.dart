import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  try {
    final options = _parseOptions(args);

    final providerName = _requiredOption(options, 'provider');
    final contentType = _parseContentType(_requiredOption(options, 'content'));
    final filter = _requiredOption(options, 'filter');
    final minecraftVersion = _requiredOption(options, 'mc-version');
    final loader = _parseLoader(_requiredOption(options, 'loader'));

    if (providerName != MtnMinecraftContentProviderModrinth.providerName) {
      throw ArgumentError('Unsupported provider: $providerName. Currently supported: modrinth.');
    }

    final provider = MtnMinecraftContentProviderModrinth(
      userAgent: 'nusretm/minecraft_tools (https://github.com/nusretm/minecraft_tools)',
    );
    final service = MtnMinecraftContentService(
      providers: <MtnMinecraftContentProvider>[provider],
    );

    try {
      print('Provider: $providerName');
      print('Content: ${contentType.name}');
      print('Filter: $filter');
      print('Minecraft: $minecraftVersion');
      print('Loader: ${loader.name}');
      print('');

      final result = await service.search(
        providerName,
        MtnMinecraftContentSearchRequest(
          query: filter,
          types: <MtnMinecraftContentType>[contentType],
          gameVersions: <String>[minecraftVersion],
          modLoaders: <MtnMinecraftModLoaderType>[loader],
          limit: 10,
        ),
      );

      final totalText = result.total?.toString() ?? '?';
      print('Results: ${result.contents.length} shown / $totalText total');
      print('');

      if (result.contents.isEmpty) {
        print('No content found.');
        return;
      }

      for (var index = 0; index < result.contents.length; index++) {
        final content = result.contents[index];
        final providerMetadata = _providerMetadata(content, providerName);
        final providerId = providerMetadata?.id ?? '?';
        final authors = content.authors.map((author) => author.name).join(', ');
        final categories = content.categories.map((category) => category.name).join(', ');

        print('[${index + 1}] ${content.name}');
        print('    type: ${content.type.name}');
        print('    provider id: $providerId');
        if (authors.isNotEmpty) print('    authors: $authors');
        if (content.summary != null) print('    summary: ${content.summary}');
        if (categories.isNotEmpty) print('    categories: $categories');
        if (content.updatedAt != null) print('    updated: ${content.updatedAt!.toIso8601String()}');
        if (content.icon != null) print('    icon: ${content.icon!.url}');
        print('');
      }
    } finally {
      provider.close();
    }
  } on ArgumentError catch (error) {
    stderr.writeln('Error: $error');
    stderr.writeln('');
    _printUsage(toStderr: true);
    exitCode = 64;
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 1;
  }
}

Map<String, String> _parseOptions(List<String> args) {
  const allowed = <String>{
    'provider',
    'content',
    'filter',
    'mc-version',
    'loader',
  };

  final result = <String, String>{};

  for (var index = 0; index < args.length; index++) {
    final argument = args[index];
    if (!argument.startsWith('--')) throw ArgumentError('Unexpected argument: $argument');

    final name = argument.substring(2);
    if (!allowed.contains(name)) throw ArgumentError('Unknown option: --$name');
    if (result.containsKey(name)) throw ArgumentError('Duplicate option: --$name');
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) throw ArgumentError('Missing value for --$name');

    result[name] = args[++index];
  }

  return result;
}

String _requiredOption(Map<String, String> options, String name) {
  final value = options[name]?.trim();
  if (value == null || value.isEmpty) throw ArgumentError('Missing required option: --$name');
  return value;
}

MtnMinecraftContentType _parseContentType(String value) {
  switch (value.toLowerCase()) {
    case 'mod':
      return MtnMinecraftContentType.mod;
    case 'modpack':
    case 'mod-pack':
      return MtnMinecraftContentType.modPack;
    case 'resourcepack':
    case 'resource-pack':
      return MtnMinecraftContentType.resourcePack;
    case 'shaderpack':
    case 'shader-pack':
    case 'shader':
      return MtnMinecraftContentType.shaderPack;
    case 'datapack':
    case 'data-pack':
      return MtnMinecraftContentType.dataPack;
    default:
      throw ArgumentError('Unsupported content type: $value');
  }
}

MtnMinecraftModLoaderType _parseLoader(String value) {
  switch (value.toLowerCase()) {
    case 'vanilla':
    case 'minecraft':
      return MtnMinecraftModLoaderType.vanilla;
    case 'fabric':
      return MtnMinecraftModLoaderType.fabric;
    case 'quilt':
      return MtnMinecraftModLoaderType.quilt;
    case 'forge':
      return MtnMinecraftModLoaderType.forge;
    case 'neoforge':
    case 'neo-forge':
      return MtnMinecraftModLoaderType.neoForge;
    case 'cauldron':
      return MtnMinecraftModLoaderType.cauldron;
    case 'liteloader':
    case 'lite-loader':
      return MtnMinecraftModLoaderType.liteLoader;
    default:
      throw ArgumentError('Unsupported loader: $value');
  }
}

MtnMinecraftContentProviderMetadata? _providerMetadata(MtnMinecraftContent content, String providerName) {
  for (final metadata in content.providers) {
    if (metadata.provider == providerName) return metadata;
  }
  return null;
}

void _printUsage({bool toStderr = false}) {
  const usage = '''
Usage:
  dart run example/mc_content.dart --provider <provider> --content <type> --filter <query> --mc-version <version> --loader <loader>

Example:
  dart run example/mc_content.dart --provider modrinth --content mod --filter "Skyblocker" --mc-version 26.1.2 --loader fabric

Currently supported providers:
  modrinth
''';

  if (toStderr) {
    stderr.write(usage);
  } else {
    stdout.write(usage);
  }
}
