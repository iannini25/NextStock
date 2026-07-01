import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/produto.dart';
import '../models/categoria.dart';

// Endereco do PROXY. O app nao fala direto com a api, passa pelo proxy (porta 8000).
// - Flutter Web e Desktop: http://127.0.0.1:8000
// - Emulador Android: troque para http://10.0.2.2:8000
//   (no emulador o 10.0.2.2 aponta pro localhost do PC)
const String baseUrl = 'http://127.0.0.1:8000';

class ApiService {
  static const headers = {'Content-Type': 'application/json'};

  // -------- CATEGORIAS --------

  static Future<List<Categoria>> listarCategorias() async {
    final r = await http.get(Uri.parse('$baseUrl/categorias'));
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Categoria.fromJson(e)).toList();
  }

  static Future<void> criarCategoria(Categoria c) async {
    final r = await http.post(Uri.parse('$baseUrl/categorias'),
        headers: headers, body: jsonEncode(c.toJson()));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  static Future<void> atualizarCategoria(int id, Categoria c) async {
    final r = await http.put(Uri.parse('$baseUrl/categorias/$id'),
        headers: headers, body: jsonEncode(c.toJson()));
    if (r.statusCode != 200) throw pegarErro(r);
  }

  static Future<void> deletarCategoria(int id) async {
    final r = await http.delete(Uri.parse('$baseUrl/categorias/$id'));
    if (r.statusCode != 204) throw pegarErro(r);
  }

  // -------- PRODUTOS --------

  static Future<List<Produto>> listarProdutos() async {
    final r = await http.get(Uri.parse('$baseUrl/produtos'));
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Produto.fromJson(e)).toList();
  }

  static Future<void> criarProduto(Produto p) async {
    final r = await http.post(Uri.parse('$baseUrl/produtos'),
        headers: headers, body: jsonEncode(p.toJson()));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  static Future<void> atualizarProduto(int id, Produto p) async {
    final r = await http.put(Uri.parse('$baseUrl/produtos/$id'),
        headers: headers, body: jsonEncode(p.toJson()));
    if (r.statusCode != 200) throw pegarErro(r);
  }

  static Future<void> deletarProduto(int id) async {
    final r = await http.delete(Uri.parse('$baseUrl/produtos/$id'));
    if (r.statusCode != 204) throw pegarErro(r);
  }

  // pega a mensagem do campo "erro" que o backend manda
  static Exception pegarErro(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return Exception(j['erro'] ?? 'Erro na API');
    } catch (_) {
      return Exception('Erro na API (${r.statusCode})');
    }
  }
}
