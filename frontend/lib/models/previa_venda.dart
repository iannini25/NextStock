// quanto sai de um lote numa venda (na previa e depois de vender)
class SaidaLote {
  int? idLote;
  String titulo; // "Lote L-12", "Lote #3" ou "Estoque inicial"
  int quantidade;
  String? dataValidade;
  int? diasParaVencer;
  bool vencido;

  SaidaLote({
    this.idLote,
    required this.titulo,
    required this.quantidade,
    this.dataValidade,
    this.diasParaVencer,
    this.vencido = false,
  });

  factory SaidaLote.fromJson(Map<String, dynamic> j) {
    return SaidaLote(
      idLote: j['id_lote'],
      titulo: j['titulo'] ?? 'Lote',
      quantidade: j['quantidade'] ?? 0,
      dataValidade: j['data_validade'],
      diasParaVencer: j['dias_para_vencer'],
      vencido: j['vencido'] ?? false,
    );
  }

  // "5 do Lote L1 (vence em 2 dia(s))"
  String get texto {
    final d = diasParaVencer;
    String validade;
    if (d == null) {
      validade = 'sem validade';
    } else if (d < 0) {
      validade = 'VENCIDO há ${-d} dia(s)';
    } else if (d == 0) {
      validade = 'vence hoje';
    } else {
      validade = 'vence em $d dia(s)';
    }
    return '$quantidade do $titulo ($validade)';
  }
}

// de quais lotes a venda vai sair, antes de registrar
class PreviaVenda {
  bool suficiente;
  int falta;
  List<SaidaLote> lotes;
  String? aviso;

  PreviaVenda({required this.suficiente, required this.falta, required this.lotes, this.aviso});

  factory PreviaVenda.fromJson(Map<String, dynamic> j) {
    return PreviaVenda(
      suficiente: j['suficiente'] ?? false,
      falta: j['falta'] ?? 0,
      lotes: (j['lotes'] as List? ?? []).map((e) => SaidaLote.fromJson(e as Map<String, dynamic>)).toList(),
      aviso: j['aviso'],
    );
  }
}
