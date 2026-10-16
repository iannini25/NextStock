// uma vez que o NextStock buscou dados no ERP
class SincronizacaoErp {
  int id;
  String? iniciadoEm; // aaaa-mm-ddThh:mm:ss
  String status; // em_andamento | sucesso | parcial | erro
  int produtosCriados;
  int produtosAtualizados;
  int vendasImportadas;
  int vendasJaImportadas;
  List<String> erros;
  String? usuario;

  SincronizacaoErp({
    required this.id,
    this.iniciadoEm,
    required this.status,
    required this.produtosCriados,
    required this.produtosAtualizados,
    required this.vendasImportadas,
    required this.vendasJaImportadas,
    required this.erros,
    this.usuario,
  });

  factory SincronizacaoErp.fromJson(Map<String, dynamic> j) {
    return SincronizacaoErp(
      id: j['id_sincronizacao'] ?? 0,
      iniciadoEm: j['iniciado_em'],
      status: j['status'] ?? 'erro',
      produtosCriados: j['produtos_criados'] ?? 0,
      produtosAtualizados: j['produtos_atualizados'] ?? 0,
      vendasImportadas: j['vendas_importadas'] ?? 0,
      vendasJaImportadas: j['vendas_ja_importadas'] ?? 0,
      erros: (j['erros'] as List? ?? []).map((e) => e.toString()).toList(),
      usuario: j['usuario'],
    );
  }

  String get nomeStatus {
    switch (status) {
      case 'sucesso':
        return 'Sucesso';
      case 'parcial':
        return 'Concluída com erros';
      case 'em_andamento':
        return 'Em andamento';
      default:
        return 'Falhou';
    }
  }

  // "1 produto criado, 2 atualizados, 10 vendas importadas (4 já tinham vindo)"
  String get resumo {
    final partes = <String>[
      '$produtosCriados produto(s) criado(s)',
      '$produtosAtualizados atualizado(s)',
      '$vendasImportadas venda(s) importada(s)',
    ];
    var texto = partes.join(', ');
    if (vendasJaImportadas > 0) texto += ' ($vendasJaImportadas já tinham vindo antes)';
    return texto;
  }

  // dd/mm/aaaa hh:mm
  String get quando {
    final d = DateTime.tryParse(iniciadoEm ?? '');
    if (d == null) return '-';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }
}
