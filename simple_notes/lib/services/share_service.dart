import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../providers/conversation_providers.dart' show mediaStorageProvider;
import '../database/tables.dart' show MessageType;
import '../models/message.dart';
import '../storage/media_storage.dart';

/// Sprint 7 (7.5) — compartilhamento para outros apps via share sheet do
/// sistema (share_plus).
///
/// Estratégia:
/// - Copia cada arquivo de origem para `share_tmp/<uuid>/` com o **nome de
///   exibição** (o disco tem `<uuid>.<ext>`), resolvendo colisões
///   (`nome (2).ext`) e sanitizando caracteres proibidos.
/// - Junta os textos das mensagens (na ordem de `position`) e passa como
///   `text` para o share. Cada app de destino decide o que fazer (legenda,
///   etc.).
/// - `Share.shareXFiles` fora do `AppLockShield` — quem chama deve envolver
///   em `shield.run(...)`. Explicação: o `AppLockShield` é específico do
///   app; aqui a regra fica explícita no chamador (`ChatScreen`).
/// - `finally`: apaga a pasta `share_tmp/<uuid>/` inteira.
///
/// Nenhum arquivo é compartilhado por referência; cópia é descartada.
/// A varredura de abertura (`cleanupOrphans`) cobre o caso de o app ter
/// sido morto no meio do share.
class ShareService {
  final MediaStorage storage;

  ShareService(this.storage);

  static const _tmpFolder = 'share_tmp';
  final _uuid = const Uuid();

  /// Resolve os arquivos físicos das [messages] de anexo. Devolve pares
  /// (arquivo, nomeOriginal) já renomeados para o nome de exibição.
  Future<List<_ShareFile>> _materialize(List<Message> messages) async {
    final base = await getApplicationDocumentsDirectory();
    final sessionId = _uuid.v4();
    final dir = Directory(p.join(base.path, _tmpFolder, sessionId));
    await dir.create(recursive: true);

    final used = <String>{};
    final out = <_ShareFile>[];
    for (final m in messages) {
      if (m.tipo == MessageType.texto) continue;
      final relPath = m.arquivoPath;
      if (relPath == null) continue;

      final src = await storage.resolve(relPath);
      if (!await src.exists()) continue;

      final display = m.arquivoNomeExibicao?.trim().isNotEmpty == true
          ? m.arquivoNomeExibicao!.trim()
          : m.arquivoNomeOriginal?.trim().isNotEmpty == true
              ? m.arquivoNomeOriginal!.trim()
              : p.basename(src.path);

      final safe = _sanitize(display);
      final uniqueName = _uniqueName(safe, used);
      used.add(uniqueName);

      final dest = File(p.join(dir.path, uniqueName));
      try {
        await src.copy(dest.path);
        out.add(_ShareFile(file: dest, displayName: uniqueName));
      } catch (_) {
        // Um anexo indisponível não deve impedir o envio dos demais nem do
        // texto; o resultado conterá somente os arquivos copiados.
      }
    }

    return out;
  }

  /// Sanitiza nome de exibição. Mantém a extensão; proíbe `/`, `\0`,
  /// `/`, `\` (Windows/Linux/Android) e controla tamanho em 120 chars.
  String _sanitize(String name) {
    var base = name.replaceAll(RegExp(r'[\\/\x00-\x1F]'), '_');
    if (base.length > 120) {
      final ext = p.extension(base);
      final stem = base.substring(0, base.length - ext.length);
      base = stem.substring(0, 120 - ext.length) + ext;
    }
    return base.isEmpty ? 'arquivo' : base;
  }

  /// Resolve colisões `nome (2).ext`, `nome (3).ext` etc.
  String _uniqueName(String name, Set<String> used) {
    if (!used.contains(name)) return name;
    final ext = p.extension(name);
    final stem = p.basenameWithoutExtension(name);
    var i = 2;
    while (true) {
      final candidate = '$stem ($i)$ext';
      if (!used.contains(candidate)) return candidate;
      i++;
    }
  }

  /// Compartilha as [messages] via share sheet. Junta textos em ordem de
  /// `position` (uma linha em branco entre eles), copia arquivos para
  /// temporário com o nome de exibição, e chama `Share.shareXFiles`.
  ///
  /// Devolve o `ShareResult` do share_plus. Se o usuário cancelar
  /// (ou o plugin devolver algo diferente de `success`), não é erro — é
  /// apenas ausência de compartilhamento.
  ///
  /// Sempre apaga a pasta `share_tmp/<uuid>/` no `finally`.
  Future<ShareResult> shareMessages(List<Message> messages) async {
    final texts = <String>[];
    for (final m in messages) {
      if (m.tipo == MessageType.texto) {
        final t = m.conteudoTexto;
        if (t != null && t.trim().isNotEmpty) texts.add(t);
      }
    }
    final joinedText = texts.isEmpty ? null : texts.join('\n\n');

    final files = await _materialize(messages);
    final dir = files.isEmpty
        ? null
        : files.first.file.parent;

    try {
      if (files.isEmpty && joinedText == null) {
        // Não abrir a share sheet vazia: isso não representa uma ação útil
        // para o usuário.
        return const ShareResult('', ShareResultStatus.dismissed);
      }
            if (files.isEmpty) {
        return await SharePlus.instance.share(
          ShareParams(text: joinedText!),
        );
      }
      return await SharePlus.instance.share(
        ShareParams(
          files: files.map((f) => XFile(f.file.path)).toList(),
          text: joinedText,
        ),
      );
    } finally {
      if (dir != null && await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Best-effort: se falhar, a varredura de abertura cobre depois.
        }
      }
    }
  }

  /// Sprint 7 (7.5) — varre `share_tmp/` na abertura do app e apaga tudo.
  /// Cobre o caso de o processo ter morrido durante o share (invariante 19).
  Future<void> cleanupOrphans() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _tmpFolder));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {
        // Best-effort.
      }
    }
  }
}

class _ShareFile {
  final File file;
  final String displayName;
  const _ShareFile({required this.file, required this.displayName});
}

/// Provider do [ShareService]. Depende do `MediaStorage` já fornecido.
final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(ref.watch(mediaStorageProvider)),
);