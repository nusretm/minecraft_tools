class HypixelSkyBlockNewsItemIcon {
  const HypixelSkyBlockNewsItemIcon({required this.material, this.data});

  final String material;
  final int? data;

  factory HypixelSkyBlockNewsItemIcon.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockNewsItemIcon(
        material: (json['material'] as String?) ?? '',
        data: (json['data'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'material': material,
        if (data != null) 'data': data,
      };
}

class HypixelSkyBlockNewsItem {
  const HypixelSkyBlockNewsItem({
    required this.title,
    required this.text,
    required this.link,
    required this.icon,
  });

  final String title;
  final String text;
  final String link;
  final HypixelSkyBlockNewsItemIcon icon;

  String get id => link.isNotEmpty ? link : '$title|$text';

  factory HypixelSkyBlockNewsItem.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockNewsItem(
        title: (json['title'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
        link: (json['link'] as String?) ?? '',
        icon: HypixelSkyBlockNewsItemIcon.fromJson(
          Map<String, dynamic>.from((json['item'] as Map?) ?? const {}),
        ),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'text': text,
        'link': link,
        'item': icon.toJson(),
      };
}

class HypixelSkyBlockNewsHistoryEntry {
  const HypixelSkyBlockNewsHistoryEntry({
    required this.item,
    required this.firstObservedAt,
    required this.lastObservedAt,
  });

  final HypixelSkyBlockNewsItem item;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'firstObservedAt': firstObservedAt.toUtc().toIso8601String(),
        'lastObservedAt': lastObservedAt.toUtc().toIso8601String(),
      };

  factory HypixelSkyBlockNewsHistoryEntry.fromJson(Map<String, dynamic> json) =>
      HypixelSkyBlockNewsHistoryEntry(
        item: HypixelSkyBlockNewsItem.fromJson(
          Map<String, dynamic>.from((json['item'] as Map?) ?? const {}),
        ),
        firstObservedAt: DateTime.parse(json['firstObservedAt'] as String).toUtc(),
        lastObservedAt: DateTime.parse(json['lastObservedAt'] as String).toUtc(),
      );
}
