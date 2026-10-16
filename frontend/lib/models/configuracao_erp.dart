// configuracao da integracao com o ERP. a chave nunca vem inteira da API, so mascarada (ex.: ••••1a2b)
class ConfiguracaoErp {
  bool configurado;
  Map<String, String> provedores; // valor -> nome pra mostrar
  String provedor;
  String? urlBase;
  bool ativo;
  bool possuiChave;
  String? chaveMascarada;
  String? aviso;
  String? atualizadoEm; // aaaa-mm-ddThh:mm
  String? atualizadoPor;

  ConfiguracaoErp({
    required this.configurado,
    required this.provedores,
    required this.provedor,
    this.urlBase,
    required this.ativo,
    required this.possuiChave,
    this.chaveMascarada,
    this.aviso,
    this.atualizadoEm,
    this.atualizadoPor,
  });

  factory ConfiguracaoErp.fromJson(Map<String, dynamic> j) {
    final provedores = (j['provedores'] as Map<String, dynamic>? ?? {})
        .map((valor, nome) => MapEntry(valor, nome.toString()));
    return ConfiguracaoErp(
      configurado: j['configurado'] ?? false,
      provedores: provedores.isEmpty ? {'generico': 'ERP genérico (API REST)'} : provedores,
      provedor: j['provedor'] ?? 'generico',
      urlBase: j['url_base'],
      ativo: j['ativo'] ?? false,
      possuiChave: j['possui_chave'] ?? false,
      chaveMascarada: j['chave_mascarada'],
      aviso: j['aviso'],
      atualizadoEm: j['atualizado_em'],
      atualizadoPor: j['atualizado_por'],
    );
  }

  // dd/mm/aaaa hh:mm
  String? atualizadoEmFormatado() {
    final d = DateTime.tryParse(atualizadoEm ?? '');
    if (d == null) return null;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }
}
