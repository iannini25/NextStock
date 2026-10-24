import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'usuario_form.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Usuario> usuarios = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final lista = await ApiService.listarUsuarios();
      if (!mounted) return;
      setState(() {
        usuarios = lista;
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

  // abre o formulario; se passar um usuario e edicao
  Future<void> abrirForm([Usuario? u]) async {
    final salvou = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UsuarioForm(usuario: u)),
    );
    if (salvou == true) carregar();
  }

  Future<void> desativar(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('Desativar o usuário "${u.nome}"? Ele não vai mais conseguir entrar no sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.desativarUsuario(u.id!);
      carregar();
    } catch (e) {
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo usuário'),
      ),
      body: montarCorpo(),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (usuarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhum usuário cadastrado.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // espaco pro botao
      itemCount: usuarios.length,
      itemBuilder: (_, i) {
        final u = usuarios[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              u.ehAdmin ? Icons.admin_panel_settings : Icons.person,
              color: u.ativo ? null : Colors.grey,
            ),
            title: Text(u.nome),
            subtitle: Text('${u.email}  •  ${u.nomePerfil}${u.ativo ? '' : '  •  INATIVO'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => abrirForm(u),
                ),
                // ninguem desativa o proprio usuario (a API tambem barra)
                if (u.ativo && u.id != Sessao.usuario.value?.id)
                  IconButton(
                    tooltip: 'Desativar',
                    icon: const Icon(Icons.person_off, color: Colors.red),
                    onPressed: () => desativar(u),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
