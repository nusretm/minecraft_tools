class HypixelSkyBlockPerk {
  const HypixelSkyBlockPerk({required this.name, required this.description, this.minister = false});
  final String name;
  final String description;
  final bool minister;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'minister': minister,
      };

  factory HypixelSkyBlockPerk.fromJson(Map<String, dynamic> json) => HypixelSkyBlockPerk(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        minister: json['minister'] as bool? ?? false,
      );
}

class HypixelSkyBlockCandidate {
  const HypixelSkyBlockCandidate({required this.key, required this.name, required this.perks, this.votes});
  final String key;
  final String name;
  final List<HypixelSkyBlockPerk> perks;
  final int? votes;

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'perks': perks.map((e) => e.toJson()).toList(),
        if (votes != null) 'votes': votes,
      };

  factory HypixelSkyBlockCandidate.fromJson(Map<String, dynamic> json) => HypixelSkyBlockCandidate(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        perks: ((json['perks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HypixelSkyBlockPerk.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        votes: (json['votes'] as num?)?.toInt(),
      );
}

class HypixelSkyBlockElectionRound {
  const HypixelSkyBlockElectionRound({required this.year, required this.candidates});
  final int year;
  final List<HypixelSkyBlockCandidate> candidates;

  Map<String, dynamic> toJson() => {
        'year': year,
        'candidates': candidates.map((e) => e.toJson()).toList(),
      };

  factory HypixelSkyBlockElectionRound.fromJson(Map<String, dynamic> json) => HypixelSkyBlockElectionRound(
        year: (json['year'] as num?)?.toInt() ?? 0,
        candidates: ((json['candidates'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HypixelSkyBlockCandidate.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class HypixelSkyBlockMinister {
  const HypixelSkyBlockMinister({required this.key, required this.name, required this.perk});
  final String key;
  final String name;
  final HypixelSkyBlockPerk perk;

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'perk': perk.toJson(),
      };

  factory HypixelSkyBlockMinister.fromJson(Map<String, dynamic> json) => HypixelSkyBlockMinister(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        perk: HypixelSkyBlockPerk.fromJson(Map<String, dynamic>.from((json['perk'] as Map?) ?? const {})),
      );
}

class HypixelSkyBlockMayor {
  const HypixelSkyBlockMayor({required this.key, required this.name, required this.perks, this.minister, this.election});
  final String key;
  final String name;
  final List<HypixelSkyBlockPerk> perks;
  final HypixelSkyBlockMinister? minister;
  final HypixelSkyBlockElectionRound? election;

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'perks': perks.map((e) => e.toJson()).toList(),
        if (minister != null) 'minister': minister!.toJson(),
        if (election != null) 'election': election!.toJson(),
      };

  factory HypixelSkyBlockMayor.fromJson(Map<String, dynamic> json) => HypixelSkyBlockMayor(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        perks: ((json['perks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HypixelSkyBlockPerk.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        minister: json['minister'] is Map ? HypixelSkyBlockMinister.fromJson(Map<String, dynamic>.from(json['minister'] as Map)) : null,
        election: json['election'] is Map ? HypixelSkyBlockElectionRound.fromJson(Map<String, dynamic>.from(json['election'] as Map)) : null,
      );
}

class HypixelSkyBlockElection {
  const HypixelSkyBlockElection({required this.lastUpdated, required this.mayor, this.current});
  final DateTime lastUpdated;
  final HypixelSkyBlockMayor mayor;
  final HypixelSkyBlockElectionRound? current;

  factory HypixelSkyBlockElection.fromJson(Map<String, dynamic> json) => HypixelSkyBlockElection(
        lastUpdated: DateTime.fromMillisecondsSinceEpoch((json['lastUpdated'] as num?)?.toInt() ?? 0, isUtc: true),
        mayor: HypixelSkyBlockMayor.fromJson(Map<String, dynamic>.from((json['mayor'] as Map?) ?? const {})),
        current: json['current'] is Map ? HypixelSkyBlockElectionRound.fromJson(Map<String, dynamic>.from(json['current'] as Map)) : null,
      );
}
