import 'produto.dart';

const Map<String, String> nomesPrioridade = {'alta': 'Alta', 'media': 'Média', 'baixa': 'Baixa'};

// alerta de excesso (GET /alertas/excesso)
//   perecivel: parte de um lote que nao vai ser vendida antes de vencer
//   cobertura: estoque que demora demais pra vender (ou que nao tem venda prevista)
class AlertaExcesso {
  String tipo;
  String prioridade;
  String? classeAbc;
  int idProduto;
  String produtoNome;
  String? unidade;
  int? idLote;
  String? lote;
  String? dataValidade;
  int? diasParaVencer;
  int quantidadeEmRisco;
  double valorEmRisco;
  double demandaDiaria;
  int? diasCobertura;
  String mensagem;

  AlertaExcesso({
    required this.tipo,
    required this.prioridade,
    this.classeAbc,
    required this.idProduto,
    required this.produtoNome,
    this.unidade,
    this.idLote,
    this.lote,
    this.dataValidade,
    this.diasParaVencer,
    required this.quantidadeEmRisco,
    required this.valorEmRisco,
    required this.demandaDiaria,
    this.diasCobertura,
    required this.mensagem,
  });

  factory AlertaExcesso.fromJson(Map<String, dynamic> j) {
    return AlertaExcesso(
      tipo: j['tipo'] ?? '',
      prioridade: j['prioridade'] ?? 'baixa',
      classeAbc: j['classe_abc'],
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      unidade: j['unidade'],
      idLote: j['id_lote'],
      lote: j['lote'],
      dataValidade: j['data_validade'],
      diasParaVencer: j['dias_para_vencer'],
      quantidadeEmRisco: j['quantidade_em_risco'] ?? 0,
      valorEmRisco: paraDouble(j['valor_em_risco']) ?? 0,
      demandaDiaria: paraDouble(j['demanda_diaria']) ?? 0,
      diasCobertura: j['dias_cobertura'],
      mensagem: j['mensagem'] ?? '',
    );
  }

  bool get perecivel => tipo == 'perecivel';
  String get nomeTipo => perecivel ? 'Vai vencer parado' : 'Estoque demais';
}

// GET /alertas/resumo: quantos alertas tem de cada tipo (selo do menu)
class ResumoAlertas {
  int vencendo;
  int falta;
  int excesso;
  int temperatura; // locais fora da faixa ou sem leitura
  int total;
  int prioridadeAlta;

  ResumoAlertas({
    required this.vencendo,
    required this.falta,
    required this.excesso,
    this.temperatura = 0,
    required this.total,
    required this.prioridadeAlta,
  });

  factory ResumoAlertas.fromJson(Map<String, dynamic> j) {
    return ResumoAlertas(
      vencendo: j['vencendo'] ?? 0,
      falta: j['falta'] ?? 0,
      excesso: j['excesso'] ?? 0,
      temperatura: j['temperatura'] ?? 0,
      total: j['total'] ?? 0,
      prioridadeAlta: j['prioridade_alta'] ?? 0,
    );
  }

  String get descricao =>
      '$vencendo vencendo • $falta vai faltar • $excesso excesso${temperatura > 0 ? ' • $temperatura temperatura' : ''}';
}
