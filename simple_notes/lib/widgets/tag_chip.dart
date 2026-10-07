import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../utils/tag_colors.dart';

/// RF04 — seta colorida com o rótulo da Tag.
///
/// [compact] é a versão usada ao lado do balão no chat: menor, mais baixa
/// e mais estreita. A versão normal é usada nos sheets.
class TagChip extends StatelessWidget {
  final Tag tag;
  final bool compact;
  final double? maxWidth;

  const TagChip({
    super.key,
    required this.tag,
    this.compact = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final color = tagColorFromHex(tag.cor);
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final tip = compact ? 5.0 : 8.0;
    final padH = compact ? 5.0 : 8.0;
    final padV = compact ? 1.0 : 3.0;
    final fontSize = compact ? 10.0 : 12.0;
    final width = maxWidth ?? (compact ? 64.0 : 140.0);

    return ClipPath(
      clipper: _TagArrowClipper(tip),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        color: color,
        padding: EdgeInsets.fromLTRB(padH, padV, padH + tip, padV),
        child: Text(
          tag.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: compact ? 1.1 : null,
          ),
        ),
      ),
    );
  }
}

class _TagArrowClipper extends CustomClipper<Path> {
  final double tip;
  const _TagArrowClipper(this.tip);

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - tip, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - tip, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TagArrowClipper old) => old.tip != tip;
}