import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';

class UsuarioForm extends StatefulWidget {
  final Usuario? usuario;
  const UsuarioForm({super.key, this.usuario});

  @override
  State<UsuarioForm> createState() => _UsuarioFormState();
}

class _UsuarioFormState extends State<UsuarioForm> {
  final nome = TextEditingController();
  final email = TextEditingController();
  final senha = TextEditingController();
  final confirmacao = TextEditingController();
  String perfil = 'usuario';
  bool ativo = true;
  bool salvando = false;

  bool get editando => widget.usuario != null;

  // editando o proprio usuario: nao da pra mudar o proprio perfil nem se desativar
  bool get ehVoceMesmo => editando && widget.usuario!.id == Sessao.usuario.value?.id;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    if (u != null) {
      nome.text = u.nome;
      email.text = u.email;
      perfil = u.perfil;
      ativo = u.ativo;
    }
  }

  @override
  void dispose() {
    for (final c in [nome, email, senha, confirmacao]) {
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

  // na edicao a senha e opcional: em branco mantem a atual
  String? validar() {
    if (nome.text.trim().isEmpty) return 'informe o nome';
    if (email.text.trim().isEmpty) return 'informe o e-mail';
    if (!editando || senha.text.isNotEmpty) {
      if (senha.text.length < 8) return 'a senha tem que ter pelo menos 8 caracteres';
      if (senha.text != confirmacao.text) return 'as senhas não conferem';
    }
    return null;
  }

  Future<void> salvar() async {
    final erro = validar();
    if (erro != null) {
      mostrarErro(Exception(erro));
      return;
    }
    setState(() => salvando = true);
    final u = Usuario(nome: nome.text.trim(), email: email.text.trim(), perfil: perfil, ativo: ativo);
    try {
      if (editando) {
        await ApiService.atualizarUsuario(widget.usuario!.id!, u,
            senha: senha.text.isEmpty ? null : senha.text);
      } else {
        await ApiService.criarUsuario(u, senha.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar usuário' : 'Novo usuário')),
      // no computador o formulario nao estica na tela toda
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              campo(nome, 'Nome *'),
              campo(email, 'E-mail *'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: perfil,
                  decoration: InputDecoration(
                    labelText: 'Perfil',
                    border: const OutlineInputBorder(),
                    helperText: ehVoceMesmo ? 'você não pode mudar o seu próprio perfil' : null,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'usuario', child: Text('Usuário')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: ehVoceMesmo ? null : (v) => perfil = v ?? 'usuario',
                ),
              ),
              campo(senha, editando ? 'Nova senha (em branco = manter a atual)' : 'Senha (mínimo 8 caracteres) *',
                  oculto: true),
              campo(confirmacao, editando ? 'Confirmar nova senha' : 'Confirmar senha *', oculto: true),
              if (editando)
                SwitchListTile(
                  title: const Text('Ativo'),
                  subtitle: Text(ehVoceMesmo
                      ? 'você não pode desativar o seu próprio usuário'
                      : 'usuário inativo não consegue entrar no sistema'),
                  value: ativo,
                  onChanged: ehVoceMesmo ? null : (v) => setState(() => ativo = v),
                ),
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

  Widget campo(TextEditingController c, String label, {bool oculto = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: oculto,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
