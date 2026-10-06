import 'package:flutter/material.dart';

enum AttachmentAction {
  camera,
  gallery,
  video,
  videoGallery,
  audioRecord,
  audioFile,
  document,
}

/// Bottom sheet de escolha do tipo de anexo (RF02.3).
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
            _tile(context, Icons.photo_library_outlined, 'Foto da galeria',
                AttachmentAction.gallery),
            _tile(context, Icons.videocam_outlined, 'Gravar vídeo',
                AttachmentAction.video),
            _tile(context, Icons.video_library_outlined, 'Vídeo da galeria',
                AttachmentAction.videoGallery),
            _tile(context, Icons.mic_none, 'Gravar áudio',
                AttachmentAction.audioRecord),
            _tile(context, Icons.audiotrack_outlined, 'Arquivo de áudio',
                AttachmentAction.audioFile),
            _tile(context, Icons.insert_drive_file_outlined, 'Documento',
                AttachmentAction.document),
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