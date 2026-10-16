import 'package:flutter/material.dart';
import '../models/armazenamento.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'local_detalhe_screen.dart';
import 'local_form.dart';

// cor e icone da situacao de um local (usados aqui, no detalhe e nos alertas)
Color corStatusLocal(String status) {
  switch (status) {
    case 'ok':
      return Colors.green;
    case 'fora_da_faixa':
      return Colors.red;
    case 'sem_leitura':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

IconData iconeTipoLocal(String tipo) {
  switch (tipo) {
    case 'congelado':
      return Icons.ac_unit;
    case 'ambiente':
      return Icons.warehouse;
    default:
      return Icons.kitchen;
  }
}

Widget seloStatusLocal(LocalArmazenamento l) {
  final cor = corStatusLocal(l.status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.12),
      border: Border.all(color: cor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(l.nomeStatus, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold)),
  );
}

// Locais de armazenamento (geladeira, freezer, deposito...) com a ultima temperatura e a situacao.
// todo mundo ve e registra leitura; so o admin cria, edita e desativa
class ArmazenamentoScreen extends StatefulWidget {
  const ArmazenamentoScreen({super.key});

  @override
  State<ArmazenamentoScreen> createState() => _ArmazenamentoScreenState();
}

class _ArmazenamentoScreenState extends State<ArmazenamentoScreen> {
  List<LocalArmazenamento> locais = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      // o admin ve tambem os desativados (pra poder reativar)
      final r = await ApiService.listarLocais(todos: Sessao.ehAdmin);
      if (!mounted) return;
      setState(() {
        locais = r;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> novoLocal() async {
    final salvou = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LocalForm()));
    if (salvou == true) carregar();
  }

  Future<void> abrir(LocalArmazenamento l) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LocalDetalheScreen(idLocal: l.id)));
    carregar(); // pode ter registrado leitura, editado ou desativado
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Armazenamento'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: carregar)],
      ),
      floatingActionButton: Sessao.ehAdmin
          ? FloatingActionButton.extended(
              onPressed: novoLocal,
              icon: const Icon(Icons.add),
              label: const Text('Novo local'),
            )
          : null,
      body: montarCorpo(),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (locais.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Sessao.ehAdmin
                ? 'Nenhum local cadastrado. Toque em "Novo local" para cadastrar a geladeira, o freezer...'
                : 'Nenhum local cadastrado ainda. Peça para um administrador cadastrar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final problemas = locais.where((l) => l.temProblema).length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (problemas > 0)
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ListTile(
              leading: const Icon(Icons.thermostat, color: Colors.red),
              title: Text('$problemas local(is) precisam de atenção'),
              subtitle: const Text('temperatura fora da faixa ou sem leitura recente'),
            ),
          ),
        for (final l in locais) cartao(l),
      ],
    );
  }

  Widget cartao(LocalArmazenamento l) {
    final ultima = l.ultimaLeitura;
    final textoUltima = ultima == null
        ? 'sem leitura ainda'
        : 'última: ${graus(ultima.temperatura)} em ${dataHoraCurta(ultima.dataHora)}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(iconeTipoLocal(l.tipo), color: corStatusLocal(l.status)),
        title: Text(l.nome),
        subtitle: Text('${l.nomeTipo}  •  faixa ${l.faixa}\n$textoUltima  •  ${l.quantidadeProdutos} produto(s)'),
        isThreeLine: true,
        trailing: seloStatusLocal(l),
        onTap: () => abrir(l),
      ),
    );
  }
}
