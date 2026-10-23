class ResultadoImportacao {
  int importados;
  int ignorados;
  List<String> erros;

  ResultadoImportacao({
    required this.importados,
    required this.ignorados,
    required this.erros,
  });

  factory ResultadoImportacao.fromJson(Map<String, dynamic> j) {
    return ResultadoImportacao(
      importados: j['importados'] ?? 0,
      ignorados: j['ignorados'] ?? 0,
      erros: List<String>.from(j['erros'] ?? []),
    );
  }
}
