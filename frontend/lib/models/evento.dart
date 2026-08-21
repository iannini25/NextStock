class Evento {
  int? id;
  String nome;
  String dataInicio;
  String dataFim;
  int impactoPercentual;

  Evento({
    this.id,
    required this.nome,
    required this.dataInicio,
    required this.dataFim,
    this.impactoPercentual = 0,
  });

  factory Evento.fromJson(Map<String, dynamic> j) {
    return Evento(
      id: j['id_evento'],
      nome: j['nome'] ?? '',
      dataInicio: j['data_inicio'] ?? '',
      dataFim: j['data_fim'] ?? '',
      impactoPercentual: j['impacto_percentual'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'data_inicio': dataInicio,
      'data_fim': dataFim,
      'impacto_percentual': impactoPercentual,
    };
  }
}
