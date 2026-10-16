import 'package:flutter/material.dart';
import '../models/configuracao_erp.dart';
import '../models/sincronizacao_erp.dart';
import '../services/api_service.dart';

// configuracao da integracao com o ERP (so admin). a chave fica criptografada na API e so aparece mascarada.
class IntegracaoErpScreen extends StatefulWidget {
  const IntegracaoErpScreen({super.key});

  @override
  State<IntegracaoErpScreen> createState() => _IntegracaoErpScreenState();
}

class _IntegracaoErpScreenState extends State<IntegracaoErpScreen> {
  final url = TextEditingController();
  final chave = TextEditingController();
  ConfiguracaoErp? config;
  String provedor = 'generico';
  bool ativo = true;
  bool mostrarChave = false;
  bool carregando = true;
  bool salvando = false;
  List<SincronizacaoErp> historico = [];
  bool testando = false;
  bool sincronizando = false;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  @override
  void dispose() {
    url.dispose();
    chave.dispose();
    super.dispose();
  }

  void preencher(ConfiguracaoErp c) {
    config = c;
    provedor = c.provedores.containsKey(c.provedor) ? c.provedor : c.provedores.keys.first;
    url.text = c.urlBase ?? '';
    ativo = c.configurado ? c.ativo : true;
    chave.clear(); // a chave salva nunca volta pra tela
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final c = await ApiService.buscarConfiguracaoErp();
      final h = await ApiService.listarSincronizacoesErp();
      if (!mounted) return;
      setState(() {
        preencher(c);
        historico = h;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      mostrarErro(e);
    }
  }

  Future<void> carregarHistorico() async {
    try {
      final h = await ApiService.listarSincronizacoesErp();
      if (!mounted) return;
      setState(() => historico = h);
    } catch (e) {
      mostrarErro(e);
    }
  }

  Future<void> testarConexao() async {
    setState(() => testando = true);
    try {
      final msg = await ApiService.testarConexaoErp();
      if (!mounted) return;
      avisar(msg);
    } catch (e) {
      mostrarErro(e);
    }
    if (mounted) setState(() => testando = false);
  }

  Future<void> sincronizar() async {
    setState(() => sincronizando = true);
    try {
      final s = await ApiService.sincronizarErp();
      if (!mounted) return;
      avisar('Sincronização: ${s.nomeStatus.toLowerCase()} — ${s.resumo}');
    } catch (e) {
      mostrarErro(e); // a falha tambem fica no historico
    }
    if (!mounted) return;
    setState(() => sincronizando = false);
    carregarHistorico();
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void avisar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> salvar() async {
    if (url.text.trim().isEmpty) {
      mostrarErro(Exception('informe a URL do ERP'));
      return;
    }
    if (!(config?.possuiChave ?? false) && chave.text.trim().isEmpty) {
      mostrarErro(Exception('informe a chave da API do ERP'));
      return;
    }
    setState(() => salvando = true);
    try {
      final c = await ApiService.salvarConfiguracaoErp(
        provedor: provedor,
        urlBase: url.text.trim(),
        chaveApi: chave.text.trim(),
        ativo: ativo,
      );
      if (!mounted) return;
      setState(() {
        preencher(c);
        salvando = false;
      });
      avisar('Configuração do ERP salva');
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  Future<void> removerChave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Remover a chave da API do ERP? A integração para de funcionar até cadastrar outra.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final c = await ApiService.removerChaveErp();
      if (!mounted) return;
      setState(() => preencher(c));
      avisar('Chave removida');
    } catch (e) {
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integração ERP'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: carregar)],
      ),
      body: carregando ? const Center(child: CircularProgressIndicator()) : montarFormulario(),
    );
  }

  Widget montarFormulario() {
    final c = config;
    if (c == null) return const Center(child: Text('Não foi possível carregar a configuração do ERP.'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        montarSituacao(c),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: provedor,
            decoration: const InputDecoration(labelText: 'ERP', border: OutlineInputBorder()),
            items: c.provedores.entries
                .map((p) => DropdownMenuItem(value: p.key, child: Text(p.value)))
                .toList(),
            onChanged: (v) => provedor = v ?? provedor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL da API do ERP *',
              hintText: 'https://erp.minhaloja.com/api',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: chave,
            obscureText: !mostrarChave,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: c.possuiChave ? 'Nova chave da API (em branco = manter a atual)' : 'Chave da API *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: mostrarChave ? 'Esconder chave' : 'Mostrar chave',
                icon: Icon(mostrarChave ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => mostrarChave = !mostrarChave),
              ),
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Integração ativa'),
          subtitle: const Text('desligada, o NextStock não busca dados no ERP'),
          value: ativo,
          onChanged: (v) => setState(() => ativo = v),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: salvando ? null : salvar,
          child: Text(salvando ? 'Salvando...' : 'Salvar'),
        ),
        if (c.possuiChave) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: removerChave,
            icon: const Icon(Icons.key_off, color: Colors.red),
            label: const Text('Remover chave', style: TextStyle(color: Colors.red)),
          ),
        ],
        const Divider(height: 32),
        montarSincronizacao(c),
      ],
    );
  }

  // botoes de testar/sincronizar + historico
  Widget montarSincronizacao(ConfiguracaoErp c) {
    final pronto = c.configurado && c.possuiChave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sincronização', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          pronto
              ? 'Usa a configuração salva acima. Busca no ERP os produtos e as vendas que mudaram desde a última sincronização.'
              : 'Salve a URL e a chave do ERP pra poder testar e sincronizar.',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: pronto && !testando ? testarConexao : null,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(testando ? 'Testando...' : 'Testar conexão'),
            ),
            ElevatedButton.icon(
              onPressed: pronto && !sincronizando ? sincronizar : null,
              icon: sincronizando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(sincronizando ? 'Sincronizando...' : 'Sincronizar agora'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Histórico', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (historico.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhuma sincronização ainda.'),
          )
        else
          for (final s in historico) montarItemHistorico(s),
      ],
    );
  }

  Widget montarItemHistorico(SincronizacaoErp s) {
    final (icone, cor) = switch (s.status) {
      'sucesso' => (Icons.check_circle, Colors.green),
      'parcial' => (Icons.warning_amber, Colors.orange),
      'em_andamento' => (Icons.hourglass_top, Colors.blueGrey),
      _ => (Icons.error, Colors.red),
    };
    const maxErros = 3;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icone, color: cor),
        title: Text('${s.quando}  •  ${s.nomeStatus}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.status != 'erro') Text(s.resumo),
            for (final erro in s.erros.take(maxErros)) Text(erro, style: const TextStyle(color: Colors.red)),
            if (s.erros.length > maxErros) Text('e mais ${s.erros.length - maxErros} erro(s)'),
            if (s.usuario != null) Text('por ${s.usuario}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // resumo do que esta salvo hoje
  Widget montarSituacao(ConfiguracaoErp c) {
    final linhas = <String>[];
    if (!c.possuiChave) {
      linhas.add('Nenhuma chave cadastrada.');
    } else {
      linhas.add('Chave salva: ${c.chaveMascarada ?? '(não foi possível ler)'}');
    }
    final quando = c.atualizadoEmFormatado();
    if (quando != null) {
      linhas.add('Última alteração: $quando${c.atualizadoPor != null ? ' por ${c.atualizadoPor}' : ''}');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(c.possuiChave ? Icons.key : Icons.key_off),
        title: Text(linhas.first),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in linhas.skip(1)) Text(l),
            if (c.aviso != null) Text(c.aviso!, style: const TextStyle(color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}
