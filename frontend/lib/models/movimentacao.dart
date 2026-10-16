// uma linha do historico de estoque: o que entrou ou saiu, de qual lote, saldo depois, quem e quando
class Movimentacao {
  int id;
  int idProduto;
  String? produtoNome;
  String? unidade;
  int? idLote;
  String? lote; // "Lote L-12" ou "Lote #3"
  String tipo;
  String nomeTipo;
  int sinal; // 1 entrou, -1 saiu
  int quantidade;
  int? saldoProdutoApos;
  int? idVenda;
  String? usuario;
  String origem;
  String nomeOrigem;
  String? observacao;
  String? dataHora; // aaaa-mm-ddThh:mm:ss

  Movimentacao({
    required this.id,
    required this.idProduto,
    this.produtoNome,
    this.unidade,
    this.idLote,
    this.lote,
    required this.tipo,
    required this.nomeTipo,
    required this.sinal,
    required this.quantidade,
    this.saldoProdutoApos,
    this.idVenda,
    this.usuario,
    required this.origem,
    required this.nomeOrigem,
    this.observacao,
    this.dataHora,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> j) {
    return Movimentacao(
      id: j['id_movimentacao'] ?? 0,
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'],
      unidade: j['unidade'],
      idLote: j['id_lote'],
      lote: j['lote'],
      tipo: j['tipo'] ?? '',
      nomeTipo: j['nome_tipo'] ?? j['tipo'] ?? '',
      sinal: j['sinal'] ?? 0,
      quantidade: j['quantidade'] ?? 0,
      saldoProdutoApos: j['saldo_produto_apos'],
      idVenda: j['id_venda'],
      usuario: j['usuario'],
      origem: j['origem'] ?? '',
      nomeOrigem: j['nome_origem'] ?? j['origem'] ?? '',
      observacao: j['observacao'],
      dataHora: j['data_hora'],
    );
  }

  bool get entrou => sinal > 0;

  // "+20" ou "−3"
  String get quantidadeComSinal => '${entrou ? '+' : '−'}$quantidade';

  // dd/mm/aaaa hh:mm
  String get quando {
    final d = DateTime.tryParse(dataHora ?? '');
    if (d == null) return '-';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }
}

// o que o GET /movimentacoes devolve (uma pagina + o total)
class ResultadoMovimentacoes {
  List<Movimentacao> itens;
  int total;
  int pagina;
  Map<String, String> tipos; // tipo -> nome pra mostrar

  ResultadoMovimentacoes({required this.itens, required this.total, required this.pagina, required this.tipos});

  factory ResultadoMovimentacoes.fromJson(Map<String, dynamic> j) {
    return ResultadoMovimentacoes(
      itens: (j['itens'] as List? ?? []).map((e) => Movimentacao.fromJson(e as Map<String, dynamic>)).toList(),
      total: j['total'] ?? 0,
      pagina: j['pagina'] ?? 1,
      tipos: (j['tipos'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
