import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simple_notes/storage/media_storage.dart';

void main() {
  late Directory tmp;
  late MediaStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_storage_test');
    storage = MediaStorage.withBaseDir(() async => tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> makeSource(String name, List<int> bytes) async {
    final f = File(p.join(tmp.path, 'origem_$name'));
    await f.writeAsBytes(bytes);
    return f;
  }

  test('salva, lê e apaga um arquivo', () async {
    final source = await makeSource('foto.jpg', [1, 2, 3, 4, 5]);

    final stored = await storage.saveFile(source, 'conv1');

    expect(stored.relativePath, startsWith(p.join('media', 'conv1')));
    expect(stored.relativePath, endsWith('.jpg'));
    expect(stored.sizeBytes, 5);
    expect(stored.mimeType, 'image/jpeg');
    expect(await storage.exists(stored.relativePath), isTrue);

    final copy = await storage.resolve(stored.relativePath);
    expect(await copy.readAsBytes(), [1, 2, 3, 4, 5]);

    await storage.delete(stored.relativePath);
    expect(await storage.exists(stored.relativePath), isFalse);
  });

  test('copia sem alterar o arquivo de origem', () async {
    final source = await makeSource('doc.pdf', [9, 9, 9]);
    await storage.saveFile(source, 'conv1');
    expect(await source.exists(), isTrue);
  });

  test('delete de arquivo inexistente não lança erro', () async {
    await storage.delete('media/conv1/nao_existe.jpg');
  });

  test('deleteConversationFolder remove todos os arquivos da conversa',
      () async {
    final a = await storage.saveFile(await makeSource('a.jpg', [1]), 'conv1');
    final b = await storage.saveFile(await makeSource('b.mp3', [2]), 'conv1');
    final other =
        await storage.saveFile(await makeSource('c.jpg', [3]), 'conv2');

    await storage.deleteConversationFolder('conv1');

    expect(await storage.exists(a.relativePath), isFalse);
    expect(await storage.exists(b.relativePath), isFalse);
    expect(await storage.exists(other.relativePath), isTrue); // intacta
  });

  test('arquivo de origem inexistente lança FileSystemException', () async {
    final ghost = File(p.join(tmp.path, 'fantasma.jpg'));
    expect(
      () => storage.saveFile(ghost, 'conv1'),
      throwsA(isA<FileSystemException>()),
    );
  });
}