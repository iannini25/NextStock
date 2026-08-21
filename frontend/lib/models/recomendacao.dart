class Recomendacao {
  String tipo;
  String prioridade;
  int idProduto;
  String produtoNome;
  String mensagem;

  Recomendacao({
    required this.tipo,
    required this.prioridade,
    required this.idProduto,
    required this.produtoNome,
    required this.mensagem,
  });

  factory Recomendacao.fromJson(Map<String, dynamic> j) {
    return Recomendacao(
      tipo: j['tipo'] ?? '',
      prioridade: j['prioridade'] ?? '',
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      mensagem: j['mensagem'] ?? '',
    );
  }
}
