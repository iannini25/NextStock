import 'produto.dart';

// um lote = uma entrada de mercadoria, com quantidade, validade e custo proprios
class Lote {
  int id;
  int idProduto;
  String? produtoNome;
  String? unidade;
  String? codigoLote;
  String? dataEntrada; // aaaa-mm-dd
  String? dataValidade; // aaaa-mm-dd
  int? diasParaVencer;
  bool vencido;
  int quantidadeInicial;
  int quantidadeAtual;
  double? custoUnitario;
  String origem;
  String? usuario;
  int? posicaoSaida; // 1 = o proximo a sair numa venda
  bool venderPrimeiro;

  Lote({
    required this.id,
    required this.idProduto,
    this.produtoNome,
    this.unidade,
    this.codigoLote,
    this.dataEntrada,
    this.dataValidade,
    this.diasParaVencer,
    this.vencido = false,
    required this.quantidadeInicial,
    required this.quantidadeAtual,
    this.custoUnitario,
    this.origem = 'entrada',
    this.usuario,
    this.posicaoSaida,
    this.venderPrimeiro = false,
  });

  factory Lote.fromJson(Map<String, dynamic> j) {
    return Lote(
      id: j['id_lote'] ?? 0,
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'],
      unidade: j['unidade'],
      codigoLote: j['codigo_lote'],
      dataEntrada: j['data_entrada'],
      dataValidade: j['data_validade'],
      diasParaVencer: j['dias_para_vencer'],
      vencido: j['vencido'] ?? false,
      quantidadeInicial: j['quantidade_inicial'] ?? 0,
      quantidadeAtual: j['quantidade_atual'] ?? 0,
      custoUnitario: paraDouble(j['custo_unitario']),
      origem: j['origem'] ?? 'entrada',
      usuario: j['usuario'],
      posicaoSaida: j['posicao_saida'],
      venderPrimeiro: j['vender_primeiro'] ?? false,
    );
  }

  bool get esgotado => quantidadeAtual <= 0;

  String get titulo => (codigoLote ?? '').isNotEmpty ? 'Lote $codigoLote' : 'Lote #$id';

  String get nomeOrigem {
    switch (origem) {
      case 'inicial':
        return 'estoque inicial';
      case 'ajuste':
        return 'ajuste';
      case 'importacao':
        return 'importação';
      case 'erp':
        return 'ERP';
      default:
        return 'entrada';
    }
  }

  String get textoValidade {
    final d = diasParaVencer;
    if (dataValidade == null || d == null) return 'sem validade';
    if (d < 0) return 'VENCIDO há ${-d} dia(s)';
    if (d == 0) return 'vence HOJE';
    return 'vence em $d dia(s)';
  }
}

// o que o GET /produtos/<id>/lotes devolve
class ResultadoLotes {
  Produto produto;
  List<Lote> lotes;

  ResultadoLotes({required this.produto, required this.lotes});

  factory ResultadoLotes.fromJson(Map<String, dynamic> j) {
    return ResultadoLotes(
      produto: Produto.fromJson(j['produto'] as Map<String, dynamic>),
      lotes: (j['lotes'] as List? ?? []).map((e) => Lote.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
