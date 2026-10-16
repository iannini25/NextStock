import 'package:flutter/material.dart';
import '../models/configuracao_erp.dart';
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
      if (!mounted) return;
      setState(() {
        preencher(c);
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      mostrarErro(e);
    }
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
      ],
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
