class Recomendacao {
  String tipo;
  String prioridade;
  int idProduto;
  String produtoNome;
  String mensagem;
  int? idLote; // so nas recomendacoes de validade (retirar/promocao), que sao por lote

  Recomendacao({
    required this.tipo,
    required this.prioridade,
    required this.idProduto,
    required this.produtoNome,
    required this.mensagem,
    this.idLote,
  });

  factory Recomendacao.fromJson(Map<String, dynamic> j) {
    return Recomendacao(
      tipo: j['tipo'] ?? '',
      prioridade: j['prioridade'] ?? '',
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      mensagem: j['mensagem'] ?? '',
      idLote: j['id_lote'],
    );
  }
}
