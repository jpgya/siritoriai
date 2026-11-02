class WordEntry {
  final String word;
  final String reading;
  final String startKana;
  final String endKana;
  final String? category;
  final String? description;

  const WordEntry({
    required this.word,
    required this.reading,
    required this.startKana,
    required this.endKana,
    this.category,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordEntry &&
          runtimeType == other.runtimeType &&
          reading == other.reading;

  @override
  int get hashCode => reading.hashCode;

  @override
  String toString() => '$word ($reading)';
}
