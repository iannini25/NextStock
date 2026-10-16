import 'package:flutter/material.dart';
import '../models/empresa.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';

// dados da empresa. se ainda nao tem empresa, mostra a configuracao inicial no lugar.
class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({super.key});

  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  final nome = TextEditingController();
  final nomeFantasia = TextEditingController();
  final cnpj = TextEditingController();
  final email = TextEditingController();
  final telefone = TextEditingController();

  bool carregando = true;
  bool configurado = false;
  bool falhou = false;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  @override
  void dispose() {
    for (final c in [nome, nomeFantasia, cnpj, email, telefone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() {
      carregando = true;
      falhou = false;
    });
    try {
      final ok = await ApiService.setupConfigurado();
      final empresa = ok ? await ApiService.buscarEmpresa() : null;
      if (!mounted) return;
      setState(() {
        configurado = ok;
        if (empresa != null) preencher(empresa);
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        falhou = true;
      });
      mostrarErro(e);
    }
  }

  void preencher(Empresa e) {
    nome.text = e.nome;
    nomeFantasia.text = e.nomeFantasia ?? '';
    cnpj.text = e.cnpj ?? '';
    email.text = e.email ?? '';
    telefone.text = e.telefone ?? '';
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String? vazioViraNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> salvar() async {
    if (nome.text.trim().isEmpty) {
      mostrarErro(Exception('informe a razão social da empresa'));
      return;
    }
    setState(() => salvando = true);
    final e = Empresa(
      nome: nome.text.trim(),
      nomeFantasia: vazioViraNull(nomeFantasia),
      cnpj: vazioViraNull(cnpj),
      email: vazioViraNull(email),
      telefone: vazioViraNull(telefone),
    );
    try {
      await ApiService.atualizarEmpresa(e);
      if (!mounted) return;
      setState(() => salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados da empresa salvos')),
      );
      carregar();
    } catch (erro) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!carregando && !falhou && !configurado) {
      return SetupScreen(aoConcluir: carregar);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresa'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      body: montarCorpo(),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (falhou) return const Center(child: Text('Não foi possível carregar os dados da empresa.'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        campo(nome, 'Razão social *'),
        campo(nomeFantasia, 'Nome fantasia'),
        campo(cnpj, 'CNPJ', numero: true),
        campo(email, 'E-mail da empresa'),
        campo(telefone, 'Telefone'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: salvando ? null : salvar,
          child: Text(salvando ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }

  Widget campo(TextEditingController c, String label, {bool numero = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
