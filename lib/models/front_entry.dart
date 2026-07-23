/// A single fronting period: who was front, from when, to when.
class FrontEntry {
  String memberId;
  DateTime start;
  DateTime? end;
  String notes;

  FrontEntry({
    required this.memberId,
    required this.start,
    this.end,
    this.notes = '',
  });

  bool get isActive => end == null;

  Duration get duration => (end ?? DateTime.now()).difference(start);

  FrontEntry copyWith({
    String? memberId,
    DateTime? start,
    DateTime? end,
    bool clearEnd = false,
    String? notes,
  }) {
    return FrontEntry(
      memberId: memberId ?? this.memberId,
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
      notes: notes ?? this.notes,
    );
  }

  List<String> toCsvRow() => [
        memberId,
        start.toIso8601String(),
        end?.toIso8601String() ?? '',
        notes.replaceAll('\n', '\\n'),
      ];

  factory FrontEntry.fromCsvRow(List<dynamic> row) {
    return FrontEntry(
      memberId: row[0].toString(),
      start: DateTime.parse(row[1].toString()),
      end: (row.length > 2 && row[2].toString().trim().isNotEmpty)
          ? DateTime.parse(row[2].toString())
          : null,
      notes: row.length > 3 ? row[3].toString().replaceAll('\\n', '\n') : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'notes': notes,
        'durationSeconds': duration.inSeconds,
        'active': isActive,
      };
}
