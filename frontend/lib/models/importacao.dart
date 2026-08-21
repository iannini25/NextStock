class ResultadoImportacao {
  int produtosCriados;
  int produtosAtualizados;
  int vendasImportadas;
  List<String> erros;

  ResultadoImportacao({
    required this.produtosCriados,
    required this.produtosAtualizados,
    required this.vendasImportadas,
    required this.erros,
  });

  factory ResultadoImportacao.fromJson(Map<String, dynamic> j) {
    return ResultadoImportacao(
      produtosCriados: j['produtos_criados'] ?? 0,
      produtosAtualizados: j['produtos_atualizados'] ?? 0,
      vendasImportadas: j['vendas_importadas'] ?? 0,
      erros: List<String>.from(j['erros'] ?? []),
    );
  }
}
