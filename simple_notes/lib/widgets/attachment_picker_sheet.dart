import 'package:flutter/material.dart';

enum AttachmentAction {
  camera,
  /// Foto ou vídeo da galeria, **seleção múltipla** (Sprint 7 — 7.3).
  gallery,
  /// Gravação de vídeo única pela câmera.
  video,
  audioRecord,
  /// Áudio existente no dispositivo, seleção múltipla.
  audioFile,
  /// Documento, seleção múltipla.
  document,
}

/// Bottom sheet de escolha do tipo de anexo (RF02.3 / Sprint 7 — 7.3).
/// Devolve a [AttachmentAction] escolhida, ou null se fechado.
Future<AttachmentAction?> showAttachmentPickerSheet(BuildContext context) {
  return showModalBottomSheet<AttachmentAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tile(context, Icons.photo_camera_outlined, 'Tirar foto',
                AttachmentAction.camera),
            _tile(context, Icons.photo_library_outlined,
                'Galeria (fotos e vídeos)', AttachmentAction.gallery),
            _tile(context, Icons.videocam_outlined, 'Gravar vídeo',
                AttachmentAction.video),
            _tile(context, Icons.mic_none, 'Gravar áudio',
                AttachmentAction.audioRecord),
            _tile(context, Icons.audiotrack_outlined,
                'Áudio do dispositivo', AttachmentAction.audioFile),
            _tile(context, Icons.insert_drive_file_outlined,
                'Documentos', AttachmentAction.document),
          ],
        ),
      ),
    ),
  );
}

Widget _tile(
  BuildContext context,
  IconData icon,
  String label,
  AttachmentAction action,
) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.pop(context, action),
  );
}