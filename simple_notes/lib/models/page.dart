import 'line.dart';

class NotePage {
  final String id;
  final String? blockId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEncrypted;
  final String draftContent;
  final List<Line> lines;

  const NotePage({
    required this.id,
    this.blockId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isEncrypted = false,
    this.draftContent = '',
    this.lines = const [],
  });

  String get fullText => lines.map((l) => l.content).join('\n');
}