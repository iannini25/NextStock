import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/produto.dart';
import '../models/categoria.dart';
import '../models/venda.dart';
import '../models/evento.dart';
import '../models/previsao.dart';
import '../models/sugestao_compra.dart';
import '../models/reposicao.dart';
import '../models/importacao.dart';
import '../models/painel.dart';
import '../models/recomendacao.dart';
import '../models/relatorio.dart';
import '../models/mensagem_chat.dart';

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

  // -------- ALERTAS --------

  // produtos que vencem daqui a X dias
  static Future<List<Produto>> listarProdutosVencendo(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/produtos/vencendo?dias=$dias'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Produto.fromJson(e)).toList();
  }

  // produtos com estoque no limite (risco de faltar)
  static Future<List<Produto>> listarProdutosEmRisco() async {
    final r = await http.get(Uri.parse('$baseUrl/produtos/risco-ruptura'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Produto.fromJson(e)).toList();
  }

  static Future<List<Venda>> listarVendas(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/vendas?dias=$dias'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Venda.fromJson(e)).toList();
  }

  static Future<void> registrarVenda(Venda v) async {
    final r = await http.post(Uri.parse('$baseUrl/vendas'),
        headers: headers, body: jsonEncode(v.toJson()));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  static Future<List<Evento>> listarEventos() async {
    final r = await http.get(Uri.parse('$baseUrl/eventos'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Evento.fromJson(e)).toList();
  }

  static Future<void> criarEvento(Evento e) async {
    final r = await http.post(Uri.parse('$baseUrl/eventos'),
        headers: headers, body: jsonEncode(e.toJson()));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  static Future<void> deletarEvento(int id) async {
    final r = await http.delete(Uri.parse('$baseUrl/eventos/$id'));
    if (r.statusCode != 204) throw pegarErro(r);
  }

  static Future<ResultadoPrevisao> preverDemanda(int dias, String clima) async {
    final r = await http.get(Uri.parse('$baseUrl/previsao?dias=$dias&clima=$clima'));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return ResultadoPrevisao.fromJson(j);
  }

  static Future<List<SugestaoCompra>> sugerirCompras(int dias, String clima) async {
    final r = await http.get(Uri.parse('$baseUrl/compras/sugestoes?dias=$dias&clima=$clima'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => SugestaoCompra.fromJson(e)).toList();
  }

  static Future<List<Reposicao>> listarReposicao() async {
    final r = await http.get(Uri.parse('$baseUrl/reposicao'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Reposicao.fromJson(e)).toList();
  }

  static Future<List<int>> baixarModelo(String modulo) async {
    final r = await http.get(Uri.parse('$baseUrl/importar/modelo?modulo=$modulo'));
    if (r.statusCode != 200) throw pegarErro(r);
    return r.bodyBytes;
  }

  static Future<ResultadoImportacao> importarPlanilha(
    String modulo,
    String nomeArquivo,
    List<int> bytes,
  ) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/importar?modulo=$modulo'),
    );
    req.files.add(http.MultipartFile.fromBytes(
      'arquivo',
      bytes,
      filename: nomeArquivo,
    ));
    final enviado = await req.send();
    final r = await http.Response.fromStream(enviado);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return ResultadoImportacao.fromJson(j);
  }

  static Future<Painel> montarPainel() async {
    final r = await http.get(Uri.parse('$baseUrl/painel'));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return Painel.fromJson(j);
  }

  static Future<List<Recomendacao>> listarRecomendacoes() async {
    final r = await http.get(Uri.parse('$baseUrl/recomendacoes'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Recomendacao.fromJson(e)).toList();
  }

  static Future<RelatorioConsumo> relatorioConsumo(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/consumo?dias=$dias'));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return RelatorioConsumo.fromJson(j);
  }

  static Future<RelatorioDesempenho> relatorioDesempenho(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/desempenho?dias=$dias'));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return RelatorioDesempenho.fromJson(j);
  }

  static Future<List<Tendencia>> relatorioTendencias(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/tendencias?dias=$dias'));
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Tendencia.fromJson(e)).toList();
  }

  static Future<String> perguntarAssistente(String pergunta, List<MensagemChat> historico) async {
    final r = await http.post(Uri.parse('$baseUrl/assistente'),
        headers: headers,
        body: jsonEncode({
          'pergunta': pergunta,
          'historico': historico.map((m) => m.toJson()).toList(),
        }));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j['resposta'] ?? '';
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
