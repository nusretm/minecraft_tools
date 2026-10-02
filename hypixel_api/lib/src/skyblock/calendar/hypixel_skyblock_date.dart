class HypixelSkyBlockDate {
  const HypixelSkyBlockDate({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  static const monthNames = <String>[
    'Early Spring',
    'Spring',
    'Late Spring',
    'Early Summer',
    'Summer',
    'Late Summer',
    'Early Autumn',
    'Autumn',
    'Late Autumn',
    'Early Winter',
    'Winter',
    'Late Winter',
  ];

  String get monthName => monthNames[month - 1];

  @override
  String toString() {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    final ss = second.toString().padLeft(2, '0');
    return '$day $monthName, Year $year $hh:$mm:$ss';
  }
}
