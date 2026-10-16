import 'produto.dart';

const Map<String, String> tiposPerda = {'perda': 'Perda', 'descarte': 'Descarte'};
const Map<String, String> motivosPerda = {
  'vencimento': 'Vencimento',
  'avaria': 'Avaria',
  'temperatura': 'Temperatura',
  'furto': 'Furto',
  'outro': 'Outro',
};

// perda ou descarte de um lote, com o valor perdido
class Perda {
  int id;
  String? produtoNome;
  String? unidade;
  String? lote;
  String tipo;
  String nomeTipo;
  String motivo;
  String nomeMotivo;
  int quantidade;
  double valorTotal;
  String? observacao;
  String? usuario;
  String? dataRegistro;

  Perda({
    required this.id,
    this.produtoNome,
    this.unidade,
    this.lote,
    required this.tipo,
    required this.nomeTipo,
    required this.motivo,
    required this.nomeMotivo,
    required this.quantidade,
    required this.valorTotal,
    this.observacao,
    this.usuario,
    this.dataRegistro,
  });

  factory Perda.fromJson(Map<String, dynamic> j) {
    return Perda(
      id: j['id_perda'] ?? 0,
      produtoNome: j['produto_nome'],
      unidade: j['unidade'],
      lote: j['lote'],
      tipo: j['tipo'] ?? '',
      nomeTipo: j['nome_tipo'] ?? '',
      motivo: j['motivo'] ?? '',
      nomeMotivo: j['nome_motivo'] ?? '',
      quantidade: j['quantidade'] ?? 0,
      valorTotal: paraDouble(j['valor_total']) ?? 0,
      observacao: j['observacao'],
      usuario: j['usuario'],
      dataRegistro: j['data_registro'],
    );
  }

  // dd/mm/aaaa hh:mm
  String get quando {
    final d = DateTime.tryParse(dataRegistro ?? '');
    if (d == null) return '-';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }
}

// GET /perdas: a lista + os totais do filtro
class ListaPerdas {
  List<Perda> itens;
  double valorTotal;
  int quantidadeTotal;

  ListaPerdas({required this.itens, required this.valorTotal, required this.quantidadeTotal});

  factory ListaPerdas.fromJson(Map<String, dynamic> j) {
    return ListaPerdas(
      itens: (j['itens'] as List? ?? []).map((e) => Perda.fromJson(e as Map<String, dynamic>)).toList(),
      valorTotal: paraDouble(j['valor_total']) ?? 0,
      quantidadeTotal: j['quantidade_total'] ?? 0,
    );
  }
}

// GET /perdas/resumo: prejuizo do periodo, por motivo
class ResumoPerdas {
  double valorTotal;
  int quantidadeTotal;
  int registros;
  List<({String nome, double valor, int quantidade})> porMotivo;

  ResumoPerdas({required this.valorTotal, required this.quantidadeTotal, required this.registros, required this.porMotivo});

  factory ResumoPerdas.fromJson(Map<String, dynamic> j) {
    return ResumoPerdas(
      valorTotal: paraDouble(j['valor_total']) ?? 0,
      quantidadeTotal: j['quantidade_total'] ?? 0,
      registros: j['registros'] ?? 0,
      porMotivo: (j['por_motivo'] as List? ?? [])
          .map((m) => (nome: m['nome'].toString(), valor: paraDouble(m['valor']) ?? 0, quantidade: m['quantidade'] as int? ?? 0))
          .toList(),
    );
  }
}
