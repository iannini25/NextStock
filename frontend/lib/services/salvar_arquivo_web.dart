// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

// no Chrome, FilePicker.saveFile some depois do await da API (perde o clique).
// o <a download> ainda funciona depois da rede.
Future<void> salvarArquivo(String nome, List<int> bytes) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', nome)
    ..click();
  html.Url.revokeObjectUrl(url);
}
