import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../utils/format.dart';
import '../utils/tag_colors.dart';

/// Faixa que passa por trás da mensagem, ocupando toda a largura da linha.
///
/// Canto esquerdo: título da Tag (se houver) e, logo abaixo, a data da
/// mensagem em letra pequena. Sem Tag, a faixa não tem fundo colorido e o
/// título fica vazio, mas a data permanece na MESMA posição (padronização).
class TagRibbon extends StatelessWidget {
  final DateTime date;
  final Tag? tag;

  const TagRibbon({super.key, required this.date, this.tag});

  static const double height = 30;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = this.tag;
    final color = tag != null ? tagColorFromHex(tag.cor) : null;

    final baseText = color == null
        ? scheme.onSurfaceVariant
        : (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelMaxWidth = constraints.maxWidth * 0.25;

        return Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 8),
          decoration: color == null
              ? null
              : BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: labelMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null)
                  Text(
                    tag.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: baseText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  )
                else
                  // Reserva a linha do título para a data ficar no mesmo lugar.
                  const SizedBox(height: 12.1),
                Text(
                  formatDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: baseText.withValues(alpha: 0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}