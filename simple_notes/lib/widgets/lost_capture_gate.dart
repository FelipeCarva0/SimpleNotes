import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_providers.dart';
import '../screens/chat_screen.dart';

/// Ao abrir o app, recupera uma foto/vídeo cuja captura foi interrompida
/// porque o Android encerrou o app enquanto a câmera estava aberta.
class LostCaptureGate extends ConsumerStatefulWidget {
  final Widget child;
  const LostCaptureGate({super.key, required this.child});

  @override
  ConsumerState<LostCaptureGate> createState() => _LostCaptureGateState();
}

class _LostCaptureGateState extends ConsumerState<LostCaptureGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<void> _recover() async {
    final service = ref.read(attachmentServiceProvider);
    final repo = ref.read(conversationRepositoryProvider);

    try {
      final conversationId = await service.readPendingCapture();
      if (conversationId == null) return;

      final picked = await service.retrieveLostCapture();
      await service.clearPendingCapture();
      if (picked == null) return; // usuário cancelou a câmera

      final conversation = await repo.getById(conversationId);
      if (conversation == null) return; // conversa foi excluída

      await repo.sendAttachment(
        conversationId: conversationId,
        tipo: picked.tipo,
        file: picked.file,
        nomeOriginal: picked.nomeOriginal,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId),
        ),
      );
    } catch (e) {
      debugPrint('Falha ao recuperar captura perdida: $e');
      await service.clearPendingCapture();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}