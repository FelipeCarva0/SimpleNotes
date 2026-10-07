import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../database/tables.dart' show MessageType;

/// Anexo escolhido/capturado, ainda não salvo no storage do app.
class PickedAttachment {
  final File file;
  final String nomeOriginal;
  final MessageType tipo;

  /// true quando o arquivo é temporário criado por nós (ex.: gravação de
  /// áudio) e pode ser apagado depois de copiado para o storage.
  final bool isTemporary;

  const PickedAttachment({
    required this.file,
    required this.nomeOriginal,
    required this.tipo,
    this.isTemporary = false,
  });
}

/// Permissão negada pelo usuário (câmera ou microfone).
class AttachmentPermissionException implements Exception {
  final String message;
  const AttachmentPermissionException(this.message);
  @override
  String toString() => message;
}

/// RF02.3 — encapsula câmera, galeria, seletor de arquivos e gravador.
/// Um anexo por vez, sem compressão.
class AttachmentService {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final _uuid = const Uuid();

  String? _currentRecordingPath;

  // ----------------------------------------------------------------
  // Foto e vídeo
  // ----------------------------------------------------------------

  Future<PickedAttachment?> takePhoto() async {
    try {
      final x = await _imagePicker.pickImage(source: ImageSource.camera);
      return _fromXFile(x, MessageType.imagem);
    } catch (e) {
      throw _mapPickerError(e, 'câmera');
    }
  }

  Future<PickedAttachment?> pickImageFromGallery() async {
    try {
      final x = await _imagePicker.pickImage(source: ImageSource.gallery);
      return _fromXFile(x, MessageType.imagem);
    } catch (e) {
      throw _mapPickerError(e, 'galeria');
    }
  }

  Future<PickedAttachment?> recordVideo() async {
    try {
      final x = await _imagePicker.pickVideo(source: ImageSource.camera);
      return _fromXFile(x, MessageType.video);
    } catch (e) {
      throw _mapPickerError(e, 'câmera');
    }
  }

  Future<PickedAttachment?> pickVideoFromGallery() async {
    try {
      final x = await _imagePicker.pickVideo(source: ImageSource.gallery);
      return _fromXFile(x, MessageType.video);
    } catch (e) {
      throw _mapPickerError(e, 'galeria');
    }
  }

  // ----------------------------------------------------------------
  // Documento e áudio existente (file_picker)
  // ----------------------------------------------------------------

  Future<PickedAttachment?> pickDocument() async {
    return _pickWithFilePicker(FileType.any);
  }

  Future<PickedAttachment?> pickAudioFile() async {
    return _pickWithFilePicker(FileType.audio);
  }

  /// Escolhe um arquivo. O tipo da Mensagem é inferido pelo MIME, mas
  /// [forceType] permite impor um tipo (ex.: "áudio" no seletor de áudio).
  Future<PickedAttachment?> _pickWithFilePicker(
    FileType type, {
    MessageType? forceType,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null; // cancelado

    final file = File(path);
    final name = p.basename(path);
    return PickedAttachment(
      file: file,
      nomeOriginal: name,
      tipo: forceType ?? inferType(path),
    );
  }

  // ----------------------------------------------------------------
  // Gravador de áudio
  // ----------------------------------------------------------------

  bool _recording = false;
  bool get isRecording => _recording;

  /// Inicia a gravação. Lança [AttachmentPermissionException] se o
  /// microfone for negado.
  Future<void> startRecording() async {
    if (_recording) return;

    if (!await _recorder.hasPermission()) {
      throw const AttachmentPermissionException(
        'Permissão de microfone negada.',
      );
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'rec_${_uuid.v4()}.m4a');

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _currentRecordingPath = path;
    _recording = true;
  }

  /// Para a gravação e devolve o anexo (ou null se algo deu errado).
  Future<PickedAttachment?> stopRecording() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;
    final finalPath = path ?? _currentRecordingPath;
    _currentRecordingPath = null;
    if (finalPath == null) return null;

    final file = File(finalPath);
    if (!await file.exists()) return null;

    final stamp = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'Áudio ${stamp.year}${two(stamp.month)}${two(stamp.day)}-'
        '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}.m4a';

    return PickedAttachment(
      file: file,
      nomeOriginal: name,
      tipo: MessageType.audio,
      isTemporary: true,
    );
  }

  /// Cancela a gravação em andamento e descarta o arquivo.
  Future<void> cancelRecording() async {
    if (!_recording) return;
    await _recorder.cancel();
    _recording = false;
    _currentRecordingPath = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  /// Escolhe um arquivo do MESMO tipo da mensagem (usado em "Substituir").
  Future<PickedAttachment?> pickForReplace(MessageType tipo) async {
    switch (tipo) {
      case MessageType.imagem:
        return pickImageFromGallery();
      case MessageType.video:
        return pickVideoFromGallery();
      case MessageType.audio:
        return _pickWithFilePicker(FileType.audio, forceType: MessageType.audio);
      case MessageType.documento:
        return _pickWithFilePicker(FileType.any, forceType: MessageType.documento);
      case MessageType.texto:
        return null;
    }
  }


  // ----------------------------------------------------------------
  // Recuperação de captura perdida (Android pode matar o app durante a câmera)
  // ----------------------------------------------------------------

  Future<File> _pendingFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'pending_capture.txt'));
  }

  /// Grava em qual Conversa a captura foi pedida, ANTES de abrir a câmera.
  Future<void> markPendingCapture(String conversationId) async {
    await (await _pendingFile()).writeAsString(conversationId, flush: true);
  }

  Future<String?> readPendingCapture() async {
    final f = await _pendingFile();
    if (!await f.exists()) return null;
    final value = (await f.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> clearPendingCapture() async {
    final f = await _pendingFile();
    if (await f.exists()) await f.delete();
  }

  /// Recupera a foto/vídeo cujo resultado se perdeu quando o Android
  /// recriou o app. Só existe no Android; devolve null se não houver nada.
  Future<PickedAttachment?> retrieveLostCapture() async {
    if (!Platform.isAndroid) return null;

    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return null;

    final x = response.file ??
        (response.files != null && response.files!.isNotEmpty
            ? response.files!.first
            : null);
    if (x == null) return null;

    return response.type == RetrieveType.video
        ? _fromXFile(x, MessageType.video, prefix: 'Vídeo')
        : _fromXFile(x, MessageType.imagem, prefix: 'Foto');
  }


  // ----------------------------------------------------------------
  // Utilitários
  // ----------------------------------------------------------------

  /// Infere o [MessageType] pelo MIME; tudo que não for imagem/vídeo/áudio
  /// vira `documento`.
  static MessageType inferType(String path) {
    final mime = lookupMimeType(path) ?? '';
    if (mime.startsWith('image/')) return MessageType.imagem;
    if (mime.startsWith('video/')) return MessageType.video;
    if (mime.startsWith('audio/')) return MessageType.audio;
    return MessageType.documento;
  }

  String _friendlyName(String prefix, String originalPath) {
    final ext = p.extension(originalPath);
    final s = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '$prefix ${s.year}${two(s.month)}${two(s.day)}-'
        '${two(s.hour)}${two(s.minute)}${two(s.second)}$ext';
  }

  PickedAttachment? _fromXFile(XFile? x, MessageType tipo, {String? prefix}) {
    if (x == null) return null; // cancelado
    return PickedAttachment(
      file: File(x.path),
      nomeOriginal:
          prefix != null ? _friendlyName(prefix, x.path) : p.basename(x.path),
      tipo: tipo,
    );
  }

  Exception _mapPickerError(Object e, String origem) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('denied')) {
      return AttachmentPermissionException(
        'Permissão de $origem negada. Ative nas configurações do aparelho.',
      );
    }
    return e is Exception ? e : Exception(e.toString());
  }
}