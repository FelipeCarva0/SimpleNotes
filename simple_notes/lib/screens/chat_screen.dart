import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_providers.dart';

/// Tela da Conversa (antiga `EditorScreen`).
///
/// Na Sprint 0 esta tela só carrega e exibe o título da Conversa, deixando
/// a navegação a partir da tela inicial já funcionando de ponta a ponta. O
/// chat de Mensagens propriamente dito — balão, campo de composição,
/// rascunho persistente e envio (RF02) — é implementado a partir da
/// Sprint 1, reaproveitando `conversationRepositoryProvider` já criado
/// aqui.
class ChatScreen extends ConsumerWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync =
        ref.watch(conversationByIdProvider(conversationId));

    return Scaffold(
      appBar: AppBar(
        title: conversationAsync.when(
          data: (c) => Text(c?.titulo ?? ''),
          loading: () => const Text(''),
          error: (_, __) => const Text('Erro'),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'As mensagens desta conversa chegam na Sprint 1\n'
            '(editor de chat, rascunho persistente e envio — RF02).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
