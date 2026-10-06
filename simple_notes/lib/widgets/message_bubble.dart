import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../database/tables.dart' show MessageType;
import '../models/message.dart';
import '../providers/conversation_providers.dart';
import '../utils/format.dart';

/// Balão de uma Mensagem (RF01/RF02). Ramifica por tipo (Sprint 2).
///
/// Sprint 3 (RF04): o gesto de arrastar envolve este widget por fora.
class MessageBubble extends ConsumerWidget {
  final Message message;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isMedia =
        message.tipo == MessageType.imagem || message.tipo == MessageType.video;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: isMedia
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _content(context, scheme),
              if (message.dataEditadaManualmente)
                Padding(
                  padding: EdgeInsets.only(top: 3, right: isMedia ? 6 : 0),
                  child: Tooltip(
                    message: 'Data editada manualmente',
                    child: Icon(
                      Icons.edit_calendar_outlined,
                      size: 13,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme) {
    switch (message.tipo) {
      case MessageType.texto:
        return Text(
          message.conteudoTexto ?? '',
          style: TextStyle(color: scheme.onPrimaryContainer),
        );
      case MessageType.imagem:
        return _ImageContent(message: message);
      case MessageType.video:
        return _VideoContent(message: message);
      case MessageType.audio:
        return _FileCard(message: message, icon: Icons.audiotrack_outlined);
      case MessageType.documento:
        return _FileCard(
          message: message,
          icon: _documentIcon(message.arquivoNomeOriginal),
        );
    }
  }

  static IconData _documentIcon(String? name) {
    final ext = (name ?? '').split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// Abre o arquivo no app padrão do sistema; avisa se não puder.
Future<void> _openFile(BuildContext context, File file) async {
  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nenhum app disponível para abrir este arquivo.')),
      );
  }
}

// ---------------------------------------------------------------------
// Estado de arquivo ausente
// ---------------------------------------------------------------------

class _MissingFile extends StatelessWidget {
  const _MissingFile();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: color),
          const SizedBox(width: 8),
          Text('Arquivo indisponível', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Imagem
// ---------------------------------------------------------------------

class _ImageContent extends ConsumerStatefulWidget {
  final Message message;
  const _ImageContent({required this.message});

  @override
  ConsumerState<_ImageContent> createState() => _ImageContentState();
}

class _ImageContentState extends ConsumerState<_ImageContent> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant _ImageContent old) {
    super.didUpdateWidget(old);
    // Arquivo substituído (RF02.4): recarrega.
    if (old.message.arquivoPath != widget.message.arquivoPath) {
      _future = _resolve();
    }
  }

  Future<File?> _resolve() async {
    final path = widget.message.arquivoPath;
    if (path == null) return null;
    final storage = ref.read(mediaStorageProvider);
    final file = await storage.resolve(path);
    return await file.exists() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: size,
            height: size,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final file = snap.data;
        if (file == null) return const _MissingFile();

        final dpr = MediaQuery.of(context).devicePixelRatio;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => _openFile(context, file),
            onLongPress: null,
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * dpr).round(),
              errorBuilder: (_, _, _) => const _MissingFile(),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Vídeo (thumbnail em disco)
// ---------------------------------------------------------------------

class _VideoContent extends ConsumerStatefulWidget {
  final Message message;
  const _VideoContent({required this.message});

  @override
  ConsumerState<_VideoContent> createState() => _VideoContentState();
}

class _VideoContentState extends ConsumerState<_VideoContent> {
  late Future<_VideoData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _VideoContent old) {
    super.didUpdateWidget(old);
    if (old.message.arquivoPath != widget.message.arquivoPath) {
      _future = _load();
    }
  }

  Future<_VideoData?> _load() async {
    final path = widget.message.arquivoPath;
    if (path == null) return null;
    final storage = ref.read(mediaStorageProvider);

    final video = await storage.resolve(path);
    if (!await video.exists()) return null;

    final thumb = await storage.thumbnailFileFor(path);
    if (!await thumb.exists()) {
      try {
        await VideoThumbnail.thumbnailFile(
          video: video.path,
          thumbnailPath: thumb.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 440,
          quality: 70,
        );
      } catch (_) {
        // Sem thumbnail: segue com placeholder.
      }
    }
    return _VideoData(video, await thumb.exists() ? thumb : null);
  }

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return FutureBuilder<_VideoData?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: size,
            height: size,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snap.data;
        if (data == null) return const _MissingFile();

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => _openFile(context, data.video),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (data.thumb != null)
                    Image.file(
                      data.thumb!,
                      fit: BoxFit.cover,
                      cacheWidth: 440,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
                    )
                  else
                    const ColoredBox(color: Colors.black26),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 56, color: Colors.white70),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _Chip(text: formatBytes(widget.message.arquivoTamanhoBytes)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoData {
  final File video;
  final File? thumb;
  const _VideoData(this.video, this.thumb);
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

// ---------------------------------------------------------------------
// Cartão de arquivo (áudio e documento)
// ---------------------------------------------------------------------

class _FileCard extends ConsumerStatefulWidget {
  final Message message;
  final IconData icon;
  const _FileCard({required this.message, required this.icon});

  @override
  ConsumerState<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends ConsumerState<_FileCard> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant _FileCard old) {
    super.didUpdateWidget(old);
    if (old.message.arquivoPath != widget.message.arquivoPath) {
      _future = _resolve();
    }
  }

  Future<File?> _resolve() async {
    final path = widget.message.arquivoPath;
    if (path == null) return null;
    final file = await ref.read(mediaStorageProvider).resolve(path);
    return await file.exists() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    final name = widget.message.arquivoNomeExibicao ?? 'Arquivo';
    final size = formatBytes(widget.message.arquivoTamanhoBytes);

    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        final missing = snap.connectionState == ConnectionState.done && file == null;
        if (missing) return const _MissingFile();

        return InkWell(
          onTap: file == null ? null : () => _openFile(context, file),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 36, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontWeight: FontWeight.w500),
                    ),
                    if (size.isNotEmpty)
                      Text(size,
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}