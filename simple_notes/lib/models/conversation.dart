
class Conversation {
  final String id;
  final String titulo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final bool protegidoPorSenha;
  final String rascunho;

  const Conversation({
    required this.id,
    required this.titulo,
    required this.criadoEm,
    required this.atualizadoEm,
    this.protegidoPorSenha = false,
    this.rascunho = '',
  });
}
