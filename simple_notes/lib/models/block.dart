// models/block.dart
class Block {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isEncrypted;

  const Block({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isEncrypted = false,
  });
}