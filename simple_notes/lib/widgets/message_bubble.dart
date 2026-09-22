import 'package:flutter/material.dart';
import '../models/message.dart';

/// Balão de uma Mensagem de texto (RF01/RF02).
///
/// Pontos de extensão já previstos, sem exigir mudança na estrutura deste
/// widget:
/// - Sprint 2 (RF02.3): quando `message.tipo != MessageType.texto`, este
///   widget passa a renderizar uma miniatura/ícone de arquivo em vez do
///   texto — por ora ele assume que só existem mensagens de texto.
/// - Sprint 3 (RF04): o gesto de arrastar para definir tag envolve este
///   widget num `Dismissible`/`flutter_slidable` por fora, sem alterar o
///   que está aqui dentro.
class MessageBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Text(
                message.conteudoTexto ?? '',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              // RF02.6 — indicador discreto de que a data foi sobrescrita
              // manualmente. A data em si (por dia) já aparece no
              // separador acima do grupo de mensagens, não repetida aqui.
              if (message.dataEditadaManualmente)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Tooltip(
                    message: 'Data editada manualmente',
                    child: Icon(
                      Icons.edit_calendar_outlined,
                      size: 13,
                      color: scheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
