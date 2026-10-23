import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final senha = TextEditingController();
  bool entrando = false;

  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> entrar() async {
    if (email.text.trim().isEmpty || senha.text.isEmpty) {
      mostrarErro(Exception('informe o e-mail e a senha'));
      return;
    }
    setState(() => entrando = true);
    try {
      final r = await ApiService.login(email.text.trim(), senha.text);
      // a tela de entrada escuta a sessao e troca pro app sozinha
      await Sessao.entrar(r.token, r.usuario);
    } catch (e) {
      if (!mounted) return;
      setState(() => entrando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset('assets/logo.png', height: 72);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // tudo dentro de um card pra ficar separado do fundo
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // no escuro a logo navy some no fundo, entao fica branca (igual na barra de cima)
                    escuro
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            child: logo,
                          )
                        : logo,
                    const SizedBox(height: 16),
                    Text(
                      'Entrar no NextStock',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (Sessao.aviso != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          Sessao.aviso!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senha,
                      obscureText: true,
                      onSubmitted: (_) => entrando ? null : entrar(),
                      decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: entrando ? null : entrar,
                      child: Text(entrando ? 'Entrando...' : 'Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
