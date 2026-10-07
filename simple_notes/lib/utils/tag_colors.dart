import 'package:flutter/material.dart';

/// RF04 — paleta fixa de cores de Tag (hex, como gravado em `Tags.cor`).
const List<String> kTagPalette = [
  '#E53935', // vermelho
  '#FB8C00', // laranja
  '#FDD835', // amarelo
  '#43A047', // verde
  '#00897B', // verde-azulado
  '#1E88E5', // azul
  '#3949AB', // índigo
  '#8E24AA', // roxo
  '#D81B60', // rosa
  '#6D4C41', // marrom
];

/// Converte '#RRGGBB' em [Color]. Valor inválido cai num cinza neutro.
Color tagColorFromHex(String hex) {
  final clean = hex.replaceAll('#', '');
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return Color(value ?? 0xFF9E9E9E);
}