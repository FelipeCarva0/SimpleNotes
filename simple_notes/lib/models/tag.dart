/// RF04 — Tag (etiqueta colorida). CRUD completo entra na Sprint 3; aqui só
/// o contrato de dados, já que a tabela `Tags` faz parte da fundação de
/// schema desta Sprint 0.
class Tag {
  final String id;
  final String nome;
  final String cor;

  const Tag({
    required this.id,
    required this.nome,
    required this.cor,
  });
}
