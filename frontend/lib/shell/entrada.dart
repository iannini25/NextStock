import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/setup_screen.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'app_shell.dart';

enum _Estado { carregando, semConexao, naoConfigurado, pronto }

// primeira tela do app. decide o que mostrar:
// sem empresa -> configuracao inicial; sem login -> tela de login; logado -> o app
class Entrada extends StatefulWidget {
  const Entrada({super.key});

  @override
  State<Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<Entrada> {
  _Estado estado = _Estado.carregando;
  String erro = '';

  @override
  void initState() {
    super.initState();
    Sessao.usuario.addListener(mudouUsuario);
    verificar();
  }

  @override
  void dispose() {
    Sessao.usuario.removeListener(mudouUsuario);
    super.dispose();
  }

  // entrou ou saiu. se saiu (ou a sessao expirou), fecha as telas abertas por cima e volta pro login
  void mudouUsuario() {
    if (!mounted) return;
    if (Sessao.usuario.value == null) {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
    }
    setState(() {});
  }

  Future<void> verificar() async {
    setState(() => estado = _Estado.carregando);
    try {
      final configurado = await ApiService.setupConfigurado();
      if (!configurado) {
        await Sessao.sair(); // token antigo nao serve mais (o banco foi zerado)
        if (!mounted) return;
        setState(() => estado = _Estado.naoConfigurado);
        return;
      }
      if (Sessao.usuario.value == null) {
        await Sessao.restaurarToken();
        if (Sessao.token != null) {
          try {
            Sessao.usuario.value = await ApiService.usuarioAtual();
          } catch (e) {
            // token vencido: o ApiService ja limpou a sessao, entao so segue pro login
            if (Sessao.token != null) rethrow;
          }
        }
      }
      if (!mounted) return;
      setState(() => estado = _Estado.pronto);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        estado = _Estado.semConexao;
        erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case _Estado.carregando:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Estado.semConexao:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Não foi possível conectar à API.', textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(erro, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: verificar, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          ),
        );
      case _Estado.naoConfigurado:
        return SetupScreen(aoConcluir: verificar);
      case _Estado.pronto:
        return Sessao.usuario.value == null ? const LoginScreen() : const AppShell();
    }
  }
}
