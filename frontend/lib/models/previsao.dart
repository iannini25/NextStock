import 'clima_dia.dart';
import 'produto.dart';

class Previsao {
  int idProduto;
  String produtoNome;
  String? unidade;
  int estoqueAtual;
  double mediaDiaria;
  double fatorClima;
  int diasComEvento;
  int previsaoDemanda;

  Previsao({
    required this.idProduto,
    required this.produtoNome,
    this.unidade,
    required this.estoqueAtual,
    required this.mediaDiaria,
    required this.fatorClima,
    required this.diasComEvento,
    required this.previsaoDemanda,
  });

  factory Previsao.fromJson(Map<String, dynamic> j) {
    return Previsao(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      unidade: j['unidade'],
      estoqueAtual: j['estoque_atual'] ?? 0,
      mediaDiaria: paraDouble(j['media_diaria']) ?? 0,
      fatorClima: paraDouble(j['fator_clima']) ?? 0,
      diasComEvento: j['dias_com_evento'] ?? 0,
      previsaoDemanda: j['previsao_demanda'] ?? 0,
    );
  }
}

class ResultadoPrevisao {
  String cidade;
  String fonte;
  String clima;
  List<ClimaDia> climaDias;
  List<Previsao> previsoes;

  ResultadoPrevisao({
    required this.cidade,
    required this.fonte,
    required this.clima,
    required this.climaDias,
    required this.previsoes,
  });

  factory ResultadoPrevisao.fromJson(Map<String, dynamic> j) {
    final dias = (j['clima_dias'] as List? ?? [])
        .map((e) => ClimaDia.fromJson(e as Map<String, dynamic>))
        .toList();
    final lista = (j['previsoes'] as List? ?? [])
        .map((e) => Previsao.fromJson(e as Map<String, dynamic>))
        .toList();
    return ResultadoPrevisao(
      cidade: j['cidade'] ?? '',
      fonte: j['fonte'] ?? '',
      clima: j['clima'] ?? 'auto',
      climaDias: dias,
      previsoes: lista,
    );
  }
}
