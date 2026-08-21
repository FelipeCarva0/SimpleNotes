// models/line.dart
class Line {
  final String id;
  final String pageId;
  final int position;
  final String content;
  final DateTime date;
  final bool isDateManuallyEdited;

  const Line({
    required this.id,
    required this.pageId,
    required this.position,
    required this.content,
    required this.date,
    this.isDateManuallyEdited = false,
  });

  Line copyWith({
    int? position,
    String? content,
    DateTime? date,
    bool? isDateManuallyEdited,
  }) {
    return Line(
      id: id,
      pageId: pageId,
      position: position ?? this.position,
      content: content ?? this.content,
      date: date ?? this.date,
      isDateManuallyEdited: isDateManuallyEdited ?? this.isDateManuallyEdited,
    );
  }
}