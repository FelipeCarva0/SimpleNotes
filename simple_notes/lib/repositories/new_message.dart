import 'dart:io';
import '../database/tables.dart' show MessageType;

/// Sprint 7 (7.1a) — item a inserir por [ConversationRepository.appendMessages].
///
/// Representa **uma** mensagem nova, ainda sem `id`/`position` (o repositório
/// atribui). É deliberadamente independente dos models de domínio para deixar
/// claro que não é uma entidade persistida — só o "formato de entrada" da
/// operação de inserção em lote.
///
/// Regras:
/// - `tipo == texto`  => `texto` obrigatório; `arquivo`/`nomeOriginal` devem ser null.
/// - `tipo != texto`  => `arquivo` obrigatório; `nomeOriginal` obrigatório;
///   `nomeExibicao` é opcional (default = `nomeOriginal`).
/// - `data == null`   => usa "hoje" (dia, sem hora).
/// - `dataEditadaManualmente == true` só faz sentido com `data` explícita.
class NewMessage {
  final MessageType tipo;
  final String? texto;
  final File? arquivo;
  final String? nomeOriginal;
  final String? nomeExibicao;

  /// `null` = hoje (dia, sem hora).
  final DateTime? data;
  final bool dataEditadaManualmente;

  /// Tag já resolvida **na conversa de destino** (o chamador resolve via
  /// `TagRepository.createOrGet` no encaminhamento). `null` = sem tag.
  final String? tagId;

  const NewMessage({
    required this.tipo,
    this.texto,
    this.arquivo,
    this.nomeOriginal,
    this.nomeExibicao,
    this.data,
    this.dataEditadaManualmente = false,
    this.tagId,
  });

  // --- Construtores de conveniência (usados nos blocos 7.3/7.4/7.6) ---

  const NewMessage.texto(
    this.texto, {
    this.data,
    this.dataEditadaManualmente = false,
    this.tagId,
  })  : tipo = MessageType.texto,
        arquivo = null,
        nomeOriginal = null,
        nomeExibicao = null;

  const NewMessage.arquivo({
    required this.tipo,
    required this.arquivo,
    required this.nomeOriginal,
    this.nomeExibicao,
    this.data,
    this.dataEditadaManualmente = false,
    this.tagId,
  })  : texto = null,
        assert(tipo != MessageType.texto, 'Use NewMessage.texto para texto');

  /// Validação de consistência — chamada por
  /// [ConversationRepository.appendMessages].
  /// Devolve `null` se ok, ou a mensagem de erro (para `ArgumentError`).
  String? validate() {
    if (tipo == MessageType.texto) {
      if (texto == null || texto!.trim().isEmpty) {
        return 'Mensagem de texto sem conteúdo.';
      }
      if (arquivo != null) {
        return 'Mensagem de texto não pode ter arquivo.';
      }
      return null;
    }
    if (arquivo == null) {
      return 'Mensagem de ${tipo.name} sem arquivo.';
    }
    if (nomeOriginal == null || nomeOriginal!.isEmpty) {
      return 'Mensagem de ${tipo.name} sem nome original.';
    }
    return null;
  }
}