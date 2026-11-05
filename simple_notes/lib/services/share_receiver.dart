import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Sprint 7 (7.6) — payload recebido de outro app.
///
/// Normaliza o que o `receive_sharing_intent` entrega (texto único +
/// arquivos do cache do plugin) em um formato estável que o
/// [ShareReceiverGate] entende.
class SharedPayload {
  final String? text;
  final List<File> files;

  const SharedPayload({this.text, this.files = const []});

  bool get isEmpty => (text == null || text!.isEmpty) && files.isEmpty;
}

/// Encapsula o `ReceiveSharingIntent`. Duas entradas:
/// - [getInitialPayload] → chamar no app start (app frio).
/// - [stream] → escutar em `initState` (app aberto).
///
/// Os arquivos entregues ficam no cache do plugin; **o chamador** deve
/// apagá-los depois de copiá-los para o storage (via
/// [cleanupFiles]). O gate faz isso no `finally`.
class ShareReceiver {
  const ShareReceiver();

  Future<SharedPayload?> getInitialPayload() async {
  try {
    final items = await ReceiveSharingIntent.instance.getInitialMedia();
    if (items.isEmpty) return null;
    final payload = _fromSharedMedia(items);
    // Impede que o mesmo compartilhamento frio seja entregue novamente na
    // próxima leitura do plugin após a navegação do app.
    await ReceiveSharingIntent.instance.reset();
    return payload;
  } catch (e) {
    debugPrint('ShareReceiver.getInitialPayload: $e');
    return null;
  }
}

  Stream<SharedPayload> get stream {
    return ReceiveSharingIntent.instance.getMediaStream().map(_fromSharedMedia);
  }

  /// Apaga os arquivos do cache do plugin. Best-effort.
  Future<void> cleanupFiles(SharedPayload payload) async {
    for (final f in payload.files) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {/* ignora */}
    }
  }

  SharedPayload _fromSharedMedia(List<SharedMediaFile> items) {
    String? text;
    final files = <File>[];
    for (final m in items) {
      // Textos e URLs são preservados como texto da mensagem; o modelo não
      // cria um tipo de anexo separado para links recebidos.
      if (m.type == SharedMediaType.text) {
        final t = m.path.trim();
        if (t.isNotEmpty) text = (text == null) ? t : '$text\n$t';
      } else if (m.type == SharedMediaType.url) {
        final t = m.path.trim();
        if (t.isNotEmpty) text = (text == null) ? t : '$text\n$t';
      } else {
        // image, video, file — todos têm `path` no cache do plugin.
        final f = File(m.path);
        files.add(f);
      }
    }
    return SharedPayload(text: text, files: files);
  }
}