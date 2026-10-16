import 'produto.dart';

const Map<String, String> tiposLocal = {
  'ambiente': 'Ambiente',
  'refrigerado': 'Refrigerado',
  'congelado': 'Congelado',
};

// faixa sugerida pra cada tipo (igual a da API): preenche o formulario quando escolhe o tipo
const Map<String, (double, double)> faixasPadrao = {
  'ambiente': (15, 30),
  'refrigerado': (0, 5),
  'congelado': (-25, -18),
};

String graus(double? t) => t == null ? '-' : '${t.toStringAsFixed(1)} °C';

// dd/mm hh:mm
String dataHoraCurta(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return '-';
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
}

class LeituraTemperatura {
  int id;
  double temperatura;
  double? umidade;
  String? dataHora;
  String origem;
  String nomeOrigem;
  String? usuario;
  bool foraDaFaixa;

  LeituraTemperatura({
    required this.id,
    required this.temperatura,
    this.umidade,
    this.dataHora,
    required this.origem,
    required this.nomeOrigem,
    this.usuario,
    this.foraDaFaixa = false,
  });

  factory LeituraTemperatura.fromJson(Map<String, dynamic> j) {
    return LeituraTemperatura(
      id: j['id_leitura'] ?? 0,
      temperatura: paraDouble(j['temperatura']) ?? 0,
      umidade: paraDouble(j['umidade']),
      dataHora: j['data_hora'],
      origem: j['origem'] ?? 'manual',
      nomeOrigem: j['nome_origem'] ?? '',
      usuario: j['usuario'],
      foraDaFaixa: j['fora_da_faixa'] == true,
    );
  }
}

// produto guardado num local, com o valor parado nele
class ProdutoNoLocal {
  int id;
  String nome;
  String? unidade;
  int quantidade;
  double valor;

  ProdutoNoLocal({required this.id, required this.nome, this.unidade, required this.quantidade, required this.valor});

  factory ProdutoNoLocal.fromJson(Map<String, dynamic> j) {
    return ProdutoNoLocal(
      id: j['id_produto'] ?? 0,
      nome: j['nome'] ?? '',
      unidade: j['unidade'],
      quantidade: j['quantidade_estoque'] ?? 0,
      valor: paraDouble(j['valor']) ?? 0,
    );
  }

  // pro formulario de perda (que trabalha com Produto)
  Produto paraProduto() => Produto(id: id, nome: nome, unidade: unidade, quantidade: quantidade);
}

// local de armazenamento com a situacao atual. o mesmo formato vem na lista, no detalhe e nos alertas
class LocalArmazenamento {
  int id;
  String nome;
  String tipo;
  String nomeTipo;
  double tempMin;
  double tempMax;
  bool ativo;
  String status; // ok | fora_da_faixa | sem_leitura | inativo
  String nomeStatus;
  String? prioridade;
  LeituraTemperatura? ultimaLeitura;
  int quantidadeProdutos;
  double valorEmEstoque;
  String mensagem;
  List<ProdutoNoLocal> produtos; // so no detalhe e nos alertas

  LocalArmazenamento({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.nomeTipo,
    required this.tempMin,
    required this.tempMax,
    this.ativo = true,
    this.status = 'ok',
    this.nomeStatus = '',
    this.prioridade,
    this.ultimaLeitura,
    this.quantidadeProdutos = 0,
    this.valorEmEstoque = 0,
    this.mensagem = '',
    this.produtos = const [],
  });

  factory LocalArmazenamento.fromJson(Map<String, dynamic> j) {
    return LocalArmazenamento(
      id: j['id_local'] ?? 0,
      nome: j['nome'] ?? '',
      tipo: j['tipo'] ?? 'refrigerado',
      nomeTipo: j['nome_tipo'] ?? '',
      tempMin: paraDouble(j['temp_min']) ?? 0,
      tempMax: paraDouble(j['temp_max']) ?? 0,
      ativo: j['ativo'] != false,
      status: j['status'] ?? 'ok',
      nomeStatus: j['nome_status'] ?? '',
      prioridade: j['prioridade'],
      ultimaLeitura: j['ultima_leitura'] == null ? null : LeituraTemperatura.fromJson(j['ultima_leitura']),
      quantidadeProdutos: j['quantidade_produtos'] ?? 0,
      valorEmEstoque: paraDouble(j['valor_em_estoque']) ?? 0,
      mensagem: j['mensagem'] ?? '',
      produtos: (j['produtos'] as List? ?? []).map((e) => ProdutoNoLocal.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  String get faixa => '${graus(tempMin)} a ${graus(tempMax)}';
  bool get temProblema => status == 'fora_da_faixa' || status == 'sem_leitura';
}
