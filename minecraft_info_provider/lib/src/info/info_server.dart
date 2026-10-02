import 'dart:convert';

/// One server entry from the Java Edition `servers.dat` list.
final class MtnMinecraftInfoServer {
  const MtnMinecraftInfoServer({
    required this.name,
    required this.address,
    this.icon,
    this.hidden = false,
    this.acceptServerResourcePacks,
  });

  factory MtnMinecraftInfoServer.clone(MtnMinecraftInfoServer source) =>
      MtnMinecraftInfoServer(
        name: source.name,
        address: source.address,
        icon: source.icon,
        hidden: source.hidden,
        acceptServerResourcePacks: source.acceptServerResourcePacks,
      );

  final String name;
  final String address;

  /// Raw base64-encoded PNG payload persisted by Minecraft, when present.
  final String? icon;

  /// Whether Minecraft hides the address in its multiplayer UI.
  final bool hidden;

  /// True/false map to Minecraft's `acceptTextures` byte 1/0.
  ///
  /// Null means the tag is absent and Minecraft may ask the player.
  final bool? acceptServerResourcePacks;

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'address': address,
        if (icon != null) 'icon': icon,
        'hidden': hidden,
        if (acceptServerResourcePacks != null)
          'acceptServerResourcePacks': acceptServerResourcePacks,
      };

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => toJson();
}
