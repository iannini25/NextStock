import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> salvarArquivo(String nome, List<int> bytes) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar modelo',
    fileName: nome,
    bytes: Uint8List.fromList(bytes),
  );
}
