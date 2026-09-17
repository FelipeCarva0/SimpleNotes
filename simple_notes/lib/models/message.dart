import '../database/tables.dart' show MessageType;

class Message {
  final String id;
  final String conversationId;
  final String? tagId;
  final int position;
  final MessageType tipo;
  final String? conteudoTexto;
  final String? arquivoPath;
  final String? arquivoNomeOriginal;
  final String? arquivoNomeExibicao;
  final String? arquivoMimeType;
  final int? arquivoTamanhoBytes;
  final DateTime data;
  final bool dataEditadaManualmente;

  const Message({
    required this.id,
    required this.conversationId,
    this.tagId,
    required this.position,
    required this.tipo,
    this.conteudoTexto,
    this.arquivoPath,
    this.arquivoNomeOriginal,
    this.arquivoNomeExibicao,
    this.arquivoMimeType,
    this.arquivoTamanhoBytes,
    required this.data,
    this.dataEditadaManualmente = false,
  });
}
