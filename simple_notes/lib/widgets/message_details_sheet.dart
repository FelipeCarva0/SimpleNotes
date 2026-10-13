import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../database/tables.dart' show MessageType;
import '../models/message.dart';
import '../models/tag.dart';
import '../providers/conversation_providers.dart';
import '../utils/format.dart';
import 'tag_chip.dart';

/// Folha com todas as informações de uma Mensagem. [position] é a posição
/// (1-based) na conversa e [total] o número de mensagens.
Future<void> showMessageDetailsSheet(
  BuildContext context, {
  required Message message,
  required Tag? tag,
  required int position,
  required int total,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MessageDetailsSheet(
      message: message,
      tag: tag,
      position: position,
      total: total,
    ),
  );
}

class _MessageDetailsSheet extends ConsumerWidget {
  final Message message;
  final Tag? tag;
  final int position;
  final int total;

  const _MessageDetailsSheet({
    required this.message,
    required this.tag,
    required this.position,
    required this.total,
  });

  static String _typeLabel(MessageType t) {
    switch (t) {
      case MessageType.texto:
        return 'Texto';
      case MessageType.imagem:
        return 'Imagem';
      case MessageType.video:
        return 'Vídeo';
      case MessageType.audio:
        return 'Áudio';
      case MessageType.documento:
        return 'Documento';
    }
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final path = message.arquivoPath;
    if (path == null) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    final file = await ref.read(mediaStorageProvider).resolve(path);
    if (!await file.exists()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Arquivo indisponível.')));
      return;
    }

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Nenhum app disponível para abrir este arquivo.'),
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isText = message.tipo == MessageType.texto;
    final text = message.conteudoTexto ?? '';
    final words =
        text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final rows = <Widget>[
      _InfoRow('Tipo', Text(_typeLabel(message.tipo))),
      _InfoRow(
        'Data',
        Text(
          message.dataEditadaManualmente
              ? '${formatDate(message.data)} (editada manualmente)'
              : formatDate(message.data),
        ),
      ),
      _InfoRow(
        'Tag',
        tag == null
            ? const Text('Sem tag')
            : Align(
                alignment: Alignment.centerLeft,
                child: TagChip(tag: tag!, maxWidth: 200),
              ),
      ),
      _InfoRow('Posição', Text('Mensagem $position de $total')),
      if (isText) ...[
        _InfoRow('Caracteres', Text('${text.length}')),
        _InfoRow('Palavras', Text('$words')),
      ] else ...[
        _InfoRow('Nome', Text(message.arquivoNomeExibicao ?? '—')),
        _InfoRow('Nome original', Text(message.arquivoNomeOriginal ?? '—')),
        _InfoRow('Formato', Text(message.arquivoMimeType ?? '—')),
        _InfoRow(
          'Tamanho',
          Text(
            message.arquivoTamanhoBytes == null
                ? '—'
                : formatBytes(message.arquivoTamanhoBytes),
          ),
        ),
      ],
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Detalhes da mensagem',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...rows,
              if (!isText && message.arquivoPath != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _openFile(context, ref),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir arquivo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}