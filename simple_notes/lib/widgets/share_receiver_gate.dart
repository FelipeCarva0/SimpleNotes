import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_providers.dart';
import '../repositories/new_message.dart';
import '../screens/chat_screen.dart';
import '../screens/destination_picker_screen.dart';
import '../services/attachment_service.dart';
import '../services/share_receiver.dart';


/// Sprint 7 (7.6) — recebe compartilhamento de outros apps.
///
/// Envolve a Home em `app.dart`. Escuta o `receive_sharing_intent`:
/// - App frio → `getInitialPayload` no primeiro frame.
/// - App aberto → `stream` em `initState`.
///
/// Ao receber payload (texto + arquivos), empilha a
/// [DestinationPickerScreen] no Navigator raiz. Escolhido o destino:
/// 1) se há texto, cria **primeiro** uma mensagem de texto (S7-9);
/// 2) os arquivos viram anexos via `appendMessages` (bloco 7.3);
/// 3) volta para a Home e abre a [ChatScreen] do destino.
///
/// `finally`: apaga os arquivos do cache do plugin.
///
/// Se o app for para segundo plano enquanto o picker está aberto e a
/// sessão cair (Z1), o payload é descartado (não guardamos conteúdo de
/// terceiros em memória indefinidamente).
class ShareReceiverGate extends ConsumerStatefulWidget {
  final Widget child;
  const ShareReceiverGate({super.key, required this.child});

  @override
  ConsumerState<ShareReceiverGate> createState() => _ShareReceiverGateState();
}

class _ShareReceiverGateState extends ConsumerState<ShareReceiverGate>
    with WidgetsBindingObserver {
  static const _receiver = ShareReceiver();

  StreamSubscription<SharedPayload>? _sub;
  bool _busy = false;
  SharedPayload? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initial());
    _sub = _receiver.stream.listen(_onPayload);
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _pending != null) {
      // Ainda não escolheu destino + app foi para background. Se o Z1
      // re-bloquear, o payload perde sentido. Não é um bug descartar:
      // evita conteúdo de terceiros em memória indefinidamente.
      final payload = _pending!;
      _pending = null;
      unawaited(_receiver.cleanupFiles(payload));
    }
  }

  Future<void> _initial() async {
    final payload = await _receiver.getInitialPayload();
    if (payload == null || payload.isEmpty || !mounted) return;
    _onPayload(payload);
  }

  Future<void> _onPayload(SharedPayload payload) async {
    if (!mounted || payload.isEmpty) return;
    if (_busy) {
      // Já estamos tratando um payload. Ignora (o usuário refaz).
      unawaited(_receiver.cleanupFiles(payload));
      return;
    }

    _busy = true;
    _pending = payload;

    try {
      // 1) Escolher destino.
      final destinationId = await Navigator.of(context, rootNavigator: true)
          .push<String>(MaterialPageRoute(
        builder: (_) => DestinationPickerScreen(
          title: 'Salvar em',
          subtitle: _subtitleFor(payload),
        ),
      ));
      if (destinationId == null || !mounted) return;

      // 2) Montar as mensagens: texto primeiro (S7-9), depois arquivos.
      final items = await _buildItems(payload);
      if (items.isEmpty) {
        _showSnack('Nada para salvar.');
        return;
      }

      // 3) Inserir no destino.
      final repo = ref.read(conversationRepositoryProvider);
      try {
        await repo.appendMessages(destinationId, items);
      } catch (e) {
        debugPrint('Falha ao salvar compartilhamento: $e');
        _showSnack('Não foi possível salvar o conteúdo compartilhado.');
        return;
      }
      if (!mounted) return;

      // 4) Ir para o destino.
      final destConv = await repo.getById(destinationId);
      if (!mounted || destConv == null) return;

      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: destinationId),
      ));
    } finally {
      _pending = null;
      _busy = false;
      unawaited(_receiver.cleanupFiles(payload));
    }
  }

  String _subtitleFor(SharedPayload p) {
    final n = p.files.length;
    if (p.text != null && n > 0) {
      return '$n ${n == 1 ? 'arquivo' : 'arquivos'} + texto';
    }
    if (n > 0) {
      return '$n ${n == 1 ? 'arquivo' : 'arquivos'}';
    }
    return 'Texto';
  }

  Future<List<NewMessage>> _buildItems(SharedPayload payload) async {
    final items = <NewMessage>[];

    // Texto primeiro (S7-9).
    final text = payload.text?.trim();
    if (text != null && text.isNotEmpty) {
      items.add(NewMessage.texto(text));
    }

    // Depois os arquivos, com tipo inferido por MIME.
    for (final f in payload.files) {
      if (!await f.exists()) continue;
      final tipo = AttachmentService.inferType(f.path);
      items.add(NewMessage.arquivo(
        tipo: tipo,
        arquivo: f,
        nomeOriginal: f.uri.pathSegments.isNotEmpty
            ? f.uri.pathSegments.last
            : 'arquivo',
      ));
    }

    return items;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}