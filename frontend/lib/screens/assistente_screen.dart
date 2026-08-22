import 'package:flutter/material.dart';
import '../main.dart';
import '../models/mensagem_chat.dart';
import '../services/api_service.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  final campoPergunta = TextEditingController();
  List<MensagemChat> mensagens = [];
  bool enviando = false;

  static MensagemChat _saudacao() {
    return MensagemChat(
      papel: 'assistente',
      texto: 'Oi! Pergunta qualquer coisa sobre o seu estoque.',
    );
  }

  @override
  void initState() {
    super.initState();
    mensagens = [_saudacao()];
  }

  void limparChat() {
    setState(() {
      mensagens = [_saudacao()];
      enviando = false;
    });
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> enviar() async {
    final pergunta = campoPergunta.text.trim();
    if (pergunta.isEmpty) return;
    final historico = List.of(mensagens);
    setState(() {
      mensagens.add(MensagemChat(papel: 'usuario', texto: pergunta));
      campoPergunta.clear();
      enviando = true;
    });
    try {
      final resposta = await ApiService.perguntarAssistente(pergunta, historico);
      if (!mounted) return;
      setState(() {
        mensagens.add(MensagemChat(papel: 'assistente', texto: resposta));
        enviando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => enviando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente'),
        actions: [
          IconButton(
            tooltip: 'Limpar conversa',
            icon: const Icon(Icons.delete_outline),
            onPressed: limparChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: montarMensagens()),
          montarCampo(),
        ],
      ),
    );
  }

  Widget montarMensagens() {
    return ListView.builder(
      itemCount: mensagens.length,
      itemBuilder: (_, i) {
        final m = mensagens[i];
        final ehUsuario = m.papel == 'usuario';
        return ListTile(
          leading: Icon(
            ehUsuario ? Icons.person : Icons.smart_toy,
            color: corAzul,
          ),
          title: Text(ehUsuario ? 'Você' : 'Assistente'),
          subtitle: Text(m.texto),
        );
      },
    );
  }

  Widget montarCampo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: campoPergunta,
              decoration: const InputDecoration(
                labelText: 'Sua pergunta',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => enviar(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: corAzul),
            onPressed: enviando ? null : enviar,
          ),
        ],
      ),
    );
  }
}
