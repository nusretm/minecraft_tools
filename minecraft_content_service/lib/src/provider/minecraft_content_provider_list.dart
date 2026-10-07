import 'minecraft_content_provider.dart';

class MtnMinecraftContentProviderList {
  MtnMinecraftContentProviderList([
    Iterable<MtnMinecraftContentProvider> providers = const <MtnMinecraftContentProvider>[],
  ]) {
    for (final provider in providers) {
      register(provider);
    }
  }

  final List<MtnMinecraftContentProvider> _providers = <MtnMinecraftContentProvider>[];

  List<MtnMinecraftContentProvider> get items => List<MtnMinecraftContentProvider>.unmodifiable(_providers);

  List<MtnMinecraftContentProvider> get readyItems => List<MtnMinecraftContentProvider>.unmodifiable(_providers.where((provider) => provider.ready));

  int get length => _providers.length;

  bool get isEmpty => _providers.isEmpty;

  bool get isNotEmpty => _providers.isNotEmpty;

  void register(MtnMinecraftContentProvider provider) {
    if (getFromName(provider.name) != null) throw StateError('Minecraft content provider is already registered: ${provider.name}');
    _providers.add(provider);
  }

  bool unregister(String name) {
    final provider = getFromName(name);
    if (provider == null) return false;
    return _providers.remove(provider);
  }

  MtnMinecraftContentProvider? getFromName(String name) {
    for (final provider in _providers) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  MtnMinecraftContentProvider requireFromName(String name) {
    final provider = getFromName(name);
    if (provider == null) throw StateError('Minecraft content provider is not registered: $name');
    return provider;
  }

  MtnMinecraftContentProvider requireReadyFromName(String name) {
    return requireFromName(name).requireReady();
  }
}
