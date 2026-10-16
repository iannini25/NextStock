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
import '../models/clima_dia.dart';
import '../models/empresa.dart';
import '../models/usuario.dart';
import '../models/configuracao_erp.dart';
import '../models/sincronizacao_erp.dart';
import 'sessao.dart';

// Endereco do PROXY. O app nao fala direto com a api, passa pelo proxy (porta 8000).
// - Flutter Web e Desktop: http://127.0.0.1:8000
// - Emulador Android: troque para http://10.0.2.2:8000
//   (no emulador o 10.0.2.2 aponta pro localhost do PC)
const String baseUrl = 'http://127.0.0.1:8000';

class ApiService {
  // toda chamada leva o token de quem esta logado (a API recusa sem ele)
  static Map<String, String> get autorizacao =>
      Sessao.token == null ? {} : {'Authorization': 'Bearer ${Sessao.token}'};

  static Map<String, String> get headers => {'Content-Type': 'application/json', ...autorizacao};

  // -------- LOGIN --------

  static Future<({String token, Usuario usuario})> login(String email, String senha) async {
    final r = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: headers, body: jsonEncode({'email': email, 'senha': senha}));
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return (token: j['token'] as String, usuario: Usuario.fromJson(j['usuario']));
  }

  // confere se o token salvo ainda vale e devolve quem esta logado
  static Future<Usuario> usuarioAtual() async {
    final r = await http.get(Uri.parse('$baseUrl/auth/me'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return Usuario.fromJson(j['usuario']);
  }

  // -------- CATEGORIAS --------

  static Future<List<Categoria>> listarCategorias() async {
    final r = await http.get(Uri.parse('$baseUrl/categorias'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
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
    final r = await http.delete(Uri.parse('$baseUrl/categorias/$id'), headers: autorizacao);
    if (r.statusCode != 204) throw pegarErro(r);
  }

  // -------- PRODUTOS --------

  // filtros opcionais; sem nenhum, traz todos os produtos (como a tela de vendas usa)
  static Future<List<Produto>> listarProdutos({String? busca, int? idCategoria, String? situacao}) async {
    final filtros = {
      if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      'id_categoria': ?idCategoria?.toString(),
      'situacao': ?situacao,
    };
    final url = Uri.parse('$baseUrl/produtos').replace(queryParameters: filtros.isEmpty ? null : filtros);
    final r = await http.get(url, headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
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
    final r = await http.delete(Uri.parse('$baseUrl/produtos/$id'), headers: autorizacao);
    if (r.statusCode != 204) throw pegarErro(r);
  }

  // -------- ALERTAS --------

  // produtos que vencem daqui a X dias
  static Future<List<Produto>> listarProdutosVencendo(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/produtos/vencendo?dias=$dias'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Produto.fromJson(e)).toList();
  }

  // produtos com estoque no limite (risco de faltar)
  static Future<List<Produto>> listarProdutosEmRisco() async {
    final r = await http.get(Uri.parse('$baseUrl/produtos/risco-ruptura'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Produto.fromJson(e)).toList();
  }

  static Future<List<Venda>> listarVendas(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/vendas?dias=$dias'), headers: autorizacao);
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
    final r = await http.get(Uri.parse('$baseUrl/eventos'), headers: autorizacao);
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
    final r = await http.delete(Uri.parse('$baseUrl/eventos/$id'), headers: autorizacao);
    if (r.statusCode != 204) throw pegarErro(r);
  }

  static Future<ResultadoPrevisao> preverDemanda(int dias, String clima) async {
    final r = await http.get(Uri.parse('$baseUrl/previsao?dias=$dias&clima=$clima'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return ResultadoPrevisao.fromJson(j);
  }

  static Future<List<SugestaoCompra>> sugerirCompras(int dias, String clima) async {
    final r = await http.get(Uri.parse('$baseUrl/compras/sugestoes?dias=$dias&clima=$clima'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => SugestaoCompra.fromJson(e)).toList();
  }

  static Future<List<Reposicao>> listarReposicao() async {
    final r = await http.get(Uri.parse('$baseUrl/reposicao'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Reposicao.fromJson(e)).toList();
  }

  static Future<ResultadoClima> listarClima() async {
    final r = await http.get(Uri.parse('$baseUrl/clima'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return ResultadoClima.fromJson(j);
  }

  static Future<List<int>> baixarModelo(String modulo) async {
    final r = await http.get(Uri.parse('$baseUrl/importar/modelo?modulo=$modulo'), headers: autorizacao);
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
    req.headers.addAll(autorizacao);
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
    final r = await http.get(Uri.parse('$baseUrl/painel'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return Painel.fromJson(j);
  }

  static Future<List<Recomendacao>> listarRecomendacoes() async {
    final r = await http.get(Uri.parse('$baseUrl/recomendacoes'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Recomendacao.fromJson(e)).toList();
  }

  static Future<RelatorioConsumo> relatorioConsumo(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/consumo?dias=$dias'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return RelatorioConsumo.fromJson(j);
  }

  static Future<RelatorioDesempenho> relatorioDesempenho(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/desempenho?dias=$dias'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return RelatorioDesempenho.fromJson(j);
  }

  static Future<List<Tendencia>> relatorioTendencias(int dias) async {
    final r = await http.get(Uri.parse('$baseUrl/relatorios/tendencias?dias=$dias'), headers: autorizacao);
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

  // -------- EMPRESA E USUARIOS --------

  // true quando a empresa (e o primeiro admin) ja foram cadastrados
  static Future<bool> setupConfigurado() async {
    final r = await http.get(Uri.parse('$baseUrl/setup/status'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j['configurado'] == true;
  }

  // configuracao inicial: empresa + primeiro administrador
  static Future<void> configurarEmpresa(Empresa e, Usuario admin, String senha) async {
    final r = await http.post(Uri.parse('$baseUrl/setup'),
        headers: headers,
        body: jsonEncode({'empresa': e.toJson(), 'admin': admin.toJson(senha: senha)}));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  static Future<Empresa> buscarEmpresa() async {
    final r = await http.get(Uri.parse('$baseUrl/empresa'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    return Empresa.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<void> atualizarEmpresa(Empresa e) async {
    final r = await http.put(Uri.parse('$baseUrl/empresa'),
        headers: headers, body: jsonEncode(e.toJson()));
    if (r.statusCode != 200) throw pegarErro(r);
  }

  static Future<List<Usuario>> listarUsuarios() async {
    final r = await http.get(Uri.parse('$baseUrl/usuarios'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Usuario.fromJson(e)).toList();
  }

  static Future<void> criarUsuario(Usuario u, String senha) async {
    final r = await http.post(Uri.parse('$baseUrl/usuarios'),
        headers: headers, body: jsonEncode(u.toJson(senha: senha)));
    if (r.statusCode != 201) throw pegarErro(r);
  }

  // senha null = mantem a senha atual
  static Future<void> atualizarUsuario(int id, Usuario u, {String? senha}) async {
    final r = await http.put(Uri.parse('$baseUrl/usuarios/$id'),
        headers: headers, body: jsonEncode(u.toJson(senha: senha)));
    if (r.statusCode != 200) throw pegarErro(r);
  }

  // a API nao apaga o usuario, so desativa
  static Future<void> desativarUsuario(int id) async {
    final r = await http.delete(Uri.parse('$baseUrl/usuarios/$id'), headers: autorizacao);
    if (r.statusCode != 204) throw pegarErro(r);
  }

  // -------- INTEGRACAO COM ERP --------

  static Future<ConfiguracaoErp> buscarConfiguracaoErp() async {
    final r = await http.get(Uri.parse('$baseUrl/erp/configuracao'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    return ConfiguracaoErp.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // chaveApi em branco = mantem a chave que ja esta salva
  static Future<ConfiguracaoErp> salvarConfiguracaoErp({
    required String provedor,
    required String urlBase,
    required String chaveApi,
    required bool ativo,
  }) async {
    final r = await http.put(Uri.parse('$baseUrl/erp/configuracao'),
        headers: headers,
        body: jsonEncode({'provedor': provedor, 'url_base': urlBase, 'chave_api': chaveApi, 'ativo': ativo}));
    if (r.statusCode != 200) throw pegarErro(r);
    return ConfiguracaoErp.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<ConfiguracaoErp> removerChaveErp() async {
    final r = await http.delete(Uri.parse('$baseUrl/erp/configuracao/chave'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    return ConfiguracaoErp.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // usa a configuracao salva; devolve a mensagem de sucesso (erro vira Exception com a mensagem da API)
  static Future<String> testarConexaoErp() async {
    final r = await http.post(Uri.parse('$baseUrl/erp/testar-conexao'), headers: headers);
    if (r.statusCode != 200) throw pegarErro(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j['mensagem'] ?? 'Conexão com o ERP funcionando';
  }

  static Future<SincronizacaoErp> sincronizarErp() async {
    final r = await http.post(Uri.parse('$baseUrl/erp/sincronizar'), headers: headers);
    if (r.statusCode != 200) throw pegarErro(r);
    return SincronizacaoErp.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<List<SincronizacaoErp>> listarSincronizacoesErp() async {
    final r = await http.get(Uri.parse('$baseUrl/erp/sincronizacoes'), headers: autorizacao);
    if (r.statusCode != 200) throw pegarErro(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => SincronizacaoErp.fromJson(e)).toList();
  }

  // pega a mensagem do campo "erro" que o backend manda.
  // 401 com alguem logado = sessao expirou: limpa a sessao e o app volta pro login
  static Exception pegarErro(http.Response r) {
    if (r.statusCode == 401) Sessao.expirou();
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return Exception(j['erro'] ?? 'Erro na API');
    } catch (_) {
      return Exception('Erro na API (${r.statusCode})');
    }
  }
}
