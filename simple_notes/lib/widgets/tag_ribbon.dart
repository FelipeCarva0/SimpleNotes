import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../utils/tag_colors.dart';

/// RF04 — fita colorida que passa por trás da mensagem, ocupando toda a
/// largura da linha, com o título da Tag à esquerda.
class TagRibbon extends StatelessWidget {
  final Tag tag;

  const TagRibbon({super.key, required this.tag});

  static const double height = 35;

  @override
  Widget build(BuildContext context) {
    final color = tagColorFromHex(tag.cor);
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final labelMaxWidth = MediaQuery.of(context).size.width * 0.26;

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: labelMaxWidth),
        child: Text(
          tag.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}