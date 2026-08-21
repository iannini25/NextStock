import 'produto.dart';

class Reposicao {
  int idProduto;
  String produtoNome;
  String? unidade;
  int estoqueAtual;
  int estoqueMinimo;
  double mediaDiaria;
  int diasAteMinimo;
  String prazoIdeal;
  int quantidadeIdeal;
  String urgencia;

  Reposicao({
    required this.idProduto,
    required this.produtoNome,
    this.unidade,
    required this.estoqueAtual,
    required this.estoqueMinimo,
    required this.mediaDiaria,
    required this.diasAteMinimo,
    required this.prazoIdeal,
    required this.quantidadeIdeal,
    required this.urgencia,
  });

  factory Reposicao.fromJson(Map<String, dynamic> j) {
    return Reposicao(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      unidade: j['unidade'],
      estoqueAtual: j['estoque_atual'] ?? 0,
      estoqueMinimo: j['estoque_minimo'] ?? 0,
      mediaDiaria: paraDouble(j['media_diaria']) ?? 0,
      diasAteMinimo: j['dias_ate_minimo'] ?? 0,
      prazoIdeal: j['prazo_ideal'] ?? '',
      quantidadeIdeal: j['quantidade_ideal'] ?? 0,
      urgencia: j['urgencia'] ?? '',
    );
  }
}
