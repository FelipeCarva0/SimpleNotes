import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Resultado de salvar um arquivo no armazenamento local.
class StoredMedia {
  /// Caminho RELATIVO ao diretório base (é isto que vai para o banco).
  final String relativePath;
  final int sizeBytes;
  final String? mimeType;

  const StoredMedia({
    required this.relativePath,
    required this.sizeBytes,
    required this.mimeType,
  });
}

/// RF07 — guarda os arquivos binários no filesystem do dispositivo.
/// O banco guarda apenas o caminho relativo + metadados (RNF03).
class MediaStorage {
  final Future<Directory> Function() _baseDirProvider;
  final _uuid = const Uuid();

  static const _rootFolder = 'media';

  /// Uso normal do app: base = diretório de documentos.
  MediaStorage() : _baseDirProvider = getApplicationDocumentsDirectory;

  /// Uso em testes: base injetada (ex.: diretório temporário).
  MediaStorage.withBaseDir(Future<Directory> Function() baseDirProvider)
      : _baseDirProvider = baseDirProvider;

  /// Copia [source] para `media/<conversationId>/<uuid>.<ext>`.
  /// O arquivo original NÃO é alterado nem movido.
  Future<StoredMedia> saveFile(File source, String conversationId) async {
    if (!await source.exists()) {
      throw FileSystemException('Arquivo de origem não existe', source.path);
    }

    final ext = p.extension(source.path); // inclui o ponto, ex.: ".jpg"
    final relative = p.join(_rootFolder, conversationId, '${_uuid.v4()}$ext');
    final destination = File(await _absolute(relative));

    await destination.parent.create(recursive: true);

    try {
      await source.copy(destination.path);
      final size = await destination.length();
      final mime = lookupMimeType(source.path);
      return StoredMedia(
        relativePath: relative,
        sizeBytes: size,
        mimeType: mime,
      );
    } catch (_) {
      // Evita deixar arquivo parcial/órfão se a cópia falhar no meio.
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  /// Converte caminho relativo (do banco) em [File] utilizável.
  Future<File> resolve(String relativePath) async {
    return File(await _absolute(relativePath));
  }

  /// Existe fisicamente? (usado pelo bubble para o estado "arquivo ausente")
  Future<bool> exists(String relativePath) async {
    return (await resolve(relativePath)).exists();
  }

  /// Apaga um arquivo. Não falha se ele já não existir.
  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) await file.delete();
  }

  /// Apaga a pasta inteira de mídia de uma Conversa (usado ao excluí-la).
  Future<void> deleteConversationFolder(String conversationId) async {
    final dir = Directory(
      await _absolute(p.join(_rootFolder, conversationId)),
    );
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<String> _absolute(String relativePath) async {
    final base = await _baseDirProvider();
    return p.join(base.path, relativePath);
  }
}