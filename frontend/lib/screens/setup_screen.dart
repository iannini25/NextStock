import 'package:flutter/material.dart';
import '../models/empresa.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';

// configuracao inicial: cadastra a empresa e o primeiro administrador.
// aparece enquanto o sistema nao tem empresa (na Etapa 2 vira a primeira tela, antes do login).
class SetupScreen extends StatefulWidget {
  final VoidCallback? aoConcluir;
  const SetupScreen({super.key, this.aoConcluir});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final nomeEmpresa = TextEditingController();
  final nomeFantasia = TextEditingController();
  final cnpj = TextEditingController();
  final emailEmpresa = TextEditingController();
  final telefone = TextEditingController();
  final nomeAdmin = TextEditingController();
  final emailAdmin = TextEditingController();
  final senha = TextEditingController();
  final confirmacao = TextEditingController();
  bool salvando = false;

  @override
  void dispose() {
    for (final c in [
      nomeEmpresa, nomeFantasia, cnpj, emailEmpresa, telefone,
      nomeAdmin, emailAdmin, senha, confirmacao,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // confere no app o que da pra conferir antes de mandar pra API
  String? validar() {
    if (nomeEmpresa.text.trim().isEmpty) return 'informe a razão social da empresa';
    if (nomeAdmin.text.trim().isEmpty) return 'informe o seu nome';
    if (emailAdmin.text.trim().isEmpty) return 'informe o e-mail de acesso';
    if (senha.text.length < 8) return 'a senha tem que ter pelo menos 8 caracteres';
    if (senha.text != confirmacao.text) return 'as senhas não conferem';
    return null;
  }

  String? vazioViraNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> salvar() async {
    final erro = validar();
    if (erro != null) {
      mostrarErro(Exception(erro));
      return;
    }
    setState(() => salvando = true);
    final empresa = Empresa(
      nome: nomeEmpresa.text.trim(),
      nomeFantasia: vazioViraNull(nomeFantasia),
      cnpj: vazioViraNull(cnpj),
      email: vazioViraNull(emailEmpresa),
      telefone: vazioViraNull(telefone),
    );
    final admin = Usuario(nome: nomeAdmin.text.trim(), email: emailAdmin.text.trim(), perfil: 'admin');
    try {
      await ApiService.configurarEmpresa(empresa, admin, senha.text);
      if (!mounted) return;
      setState(() => salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empresa configurada')),
      );
      widget.aoConcluir?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração inicial')),
      // no computador o formulario nao estica na tela toda
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Cadastre a empresa e o primeiro administrador do NextStock.'),
              const SizedBox(height: 16),
              titulo('Empresa'),
              campo(nomeEmpresa, 'Razão social *'),
              campo(nomeFantasia, 'Nome fantasia'),
              campo(cnpj, 'CNPJ', numero: true),
              campo(emailEmpresa, 'E-mail da empresa'),
              campo(telefone, 'Telefone'),
              const SizedBox(height: 8),
              titulo('Administrador'),
              campo(nomeAdmin, 'Seu nome *'),
              campo(emailAdmin, 'E-mail de acesso *'),
              campo(senha, 'Senha (mínimo 8 caracteres) *', oculto: true),
              campo(confirmacao, 'Confirmar senha *', oculto: true),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: salvando ? null : salvar,
                child: Text(salvando ? 'Salvando...' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget campo(TextEditingController c, String label, {bool numero = false, bool oculto = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: oculto,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
