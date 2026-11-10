import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/empresa.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';

// configuracao inicial: cadastra a empresa e o primeiro administrador.
// aparece enquanto o sistema nao tem empresa (antes do login).
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
  bool verSenha = false;
  bool verConfirmacao = false;
  String? campoComErro;
  String? mensagemErro;

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

  // confere no app o que da pra conferir antes de mandar pra API.
  // os limites sao os mesmos do backend (services/utils.py).
  String? validar() {
    campoComErro = null;
    mensagemErro = null;
    String? falha(String campo, String msg) {
      campoComErro = campo;
      mensagemErro = msg;
      return msg;
    }

    if (nomeEmpresa.text.trim().isEmpty) {
      return falha('nomeEmpresa', 'informe a razão social da empresa');
    }
    if (nomeAdmin.text.trim().isEmpty) return falha('nomeAdmin', 'informe o seu nome');

    final emailAcesso = emailAdmin.text.trim().toLowerCase();
    if (emailAcesso.isEmpty) return falha('emailAdmin', 'informe o e-mail de acesso');
    if (!emailValido(emailAcesso)) return falha('emailAdmin', 'e-mail inválido');

    final emailLoja = emailEmpresa.text.trim().toLowerCase();
    if (emailLoja.isNotEmpty && !emailValido(emailLoja)) {
      return falha('emailEmpresa', 'e-mail inválido');
    }

    final digitosCnpj = soDigitos(cnpj.text);
    if (digitosCnpj.isNotEmpty && digitosCnpj.length != 14) {
      return falha('cnpj', 'CNPJ tem que ter 14 números');
    }

    final digitosTelefone = soDigitos(telefone.text);
    if (digitosTelefone.isNotEmpty && digitosTelefone.length < 10) {
      return falha('telefone', 'telefone incompleto');
    }

    if (senha.text.length < 8) {
      return falha('senha', 'a senha tem que ter pelo menos 8 caracteres');
    }
    if (senha.text.length > 128) {
      return falha('senha', 'senha pode ter no máximo 128 caracteres');
    }
    if (senha.text != confirmacao.text) return falha('confirmacao', 'as senhas não conferem');
    return null;
  }

  String? vazioViraNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> salvar() async {
    final erro = validar();
    setState(() {});
    if (erro != null) {
      mostrarErro(Exception(erro));
      return;
    }
    setState(() => salvando = true);
    final digitosCnpj = soDigitos(cnpj.text);
    final emailLoja = emailEmpresa.text.trim().toLowerCase();
    final empresa = Empresa(
      nome: nomeEmpresa.text.trim(),
      nomeFantasia: vazioViraNull(nomeFantasia),
      cnpj: digitosCnpj.isEmpty ? null : digitosCnpj,
      email: emailLoja.isEmpty ? null : emailLoja,
      telefone: vazioViraNull(telefone),
    );
    final admin = Usuario(
      nome: nomeAdmin.text.trim(),
      email: emailAdmin.text.trim().toLowerCase(),
      perfil: 'admin',
    );
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
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corBarra = escuro ? const Color(0xFF12203A) : Colors.white;
    final corIcone = escuro ? Colors.white : corNavy;

    return Scaffold(
      body: Column(
        children: [
          barra(escuro, corBarra, corIcone),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
                  children: [
                    Text(
                      'Configuração inicial',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SEU ESTOQUE SEMPRE UM PASSO À FRENTE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cadastre a empresa e o primeiro administrador do NextStock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 24),
                    secao('Empresa', Icons.storefront, [
                      campo('nomeEmpresa', nomeEmpresa, 'Razão social *',
                          limite: 150, capitalizacao: TextCapitalization.words),
                      campo('nomeFantasia', nomeFantasia, 'Nome fantasia',
                          limite: 150, capitalizacao: TextCapitalization.words),
                      campo('cnpj', cnpj, 'CNPJ',
                          ajuda: '14 números',
                          teclado: TextInputType.number,
                          mascaras: [MascaraDigitos(14, formatarCnpj)]),
                      campo('emailEmpresa', emailEmpresa, 'E-mail da empresa',
                          limite: 150, teclado: TextInputType.emailAddress),
                      campo('telefone', telefone, 'Telefone',
                          ajuda: 'DDD + número',
                          teclado: TextInputType.phone,
                          mascaras: [MascaraDigitos(11, formatarTelefone)]),
                    ]),
                    secao('Administrador', Icons.person, [
                      campo('nomeAdmin', nomeAdmin, 'Seu nome *',
                          limite: 100, capitalizacao: TextCapitalization.words),
                      campo('emailAdmin', emailAdmin, 'E-mail de acesso *',
                          limite: 150, teclado: TextInputType.emailAddress),
                      campo('senha', senha, 'Senha *',
                          ajuda: 'mínimo 8 caracteres',
                          limite: 128,
                          oculto: !verSenha,
                          aoVer: () => setState(() => verSenha = !verSenha)),
                      campo('confirmacao', confirmacao, 'Confirmar senha *',
                          limite: 128,
                          oculto: !verConfirmacao,
                          aoVer: () => setState(() => verConfirmacao = !verConfirmacao),
                          acao: TextInputAction.done,
                          ultima: true),
                    ]),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: salvando ? null : salvar,
                      child: Text(salvando ? 'Salvando...' : 'Salvar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // mesma barra da casca do app: logo, nome e o botao de tema
  Widget barra(bool escuro, Color corBarra, Color corIcone) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      color: corBarra,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 20),
                marca(escuro, 'assets/logo.png', 40),
                const SizedBox(width: 8),
                // o arquivo do nome tem bastante vazio em volta da letra;
                // corta esse vazio pra marca caber na barra e ainda dar pra ler
                SizedBox(
                  width: 220,
                  height: 34,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: marca(escuro, 'assets/nome.png', 1000),
                    ),
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: modoTema,
                  builder: (_, modo, _) {
                    final estaEscuro = modo == ThemeMode.dark;
                    return IconButton(
                      tooltip: estaEscuro ? 'Tema claro' : 'Tema escuro',
                      icon: Icon(estaEscuro ? Icons.light_mode : Icons.dark_mode, color: corIcone),
                      onPressed: alternarTema,
                    );
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget marca(bool escuro, String asset, double altura) {
    final imagem = Image.asset(asset, height: altura);
    if (!escuro) return imagem;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: imagem,
    );
  }

  Widget secao(String titulo, IconData icone, List<Widget> campos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: corAzul.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, color: corAzul, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...campos,
          ],
        ),
      ),
    );
  }

  Widget campo(
    String id,
    TextEditingController c,
    String rotulo, {
    bool oculto = false,
    VoidCallback? aoVer,
    int? limite,
    String? ajuda,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter>? mascaras,
    TextInputAction acao = TextInputAction.next,
    TextCapitalization capitalizacao = TextCapitalization.none,
    bool ultima = false,
  }) {
    final comErro = campoComErro == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: oculto,
        maxLength: limite,
        keyboardType: teclado,
        textInputAction: acao,
        textCapitalization: capitalizacao,
        inputFormatters: mascaras,
        onChanged: (_) {
          if (campoComErro == id) setState(() => campoComErro = null);
        },
        onSubmitted: ultima ? (_) => salvando ? null : salvar() : null,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          errorText: comErro ? mensagemErro : null,
          border: const OutlineInputBorder(),
          suffixIcon: aoVer == null
              ? null
              : IconButton(
                  tooltip: oculto ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: aoVer,
                  icon: Icon(oculto ? Icons.visibility : Icons.visibility_off),
                ),
        ),
      ),
    );
  }
}

// o backend guarda o cnpj so com os 14 numeros e o telefone com no maximo 20 caracteres.
// a mascara fica na tela; na hora de salvar o cnpj vai sem pontuacao.
String soDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

bool emailValido(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

String formatarCnpj(String digitos) {
  final b = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i == 2 || i == 5) b.write('.');
    if (i == 8) b.write('/');
    if (i == 12) b.write('-');
    b.write(digitos[i]);
  }
  return b.toString();
}

// 10 digitos: (00) 0000-0000. 11 digitos: (00) 00000-0000.
String formatarTelefone(String digitos) {
  if (digitos.isEmpty) return '';
  final hifen = digitos.length > 10 ? 7 : 6;
  final b = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i == 0) b.write('(');
    if (i == 2) b.write(') ');
    if (i == hifen) b.write('-');
    b.write(digitos[i]);
  }
  return b.toString();
}

// aplica a mascara e segura o cursor em cima do digito que a pessoa estava editando
class MascaraDigitos extends TextInputFormatter {
  final int limite;
  final String Function(String digitos) montar;

  MascaraDigitos(this.limite, this.montar);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final fim = novo.selection.end.clamp(0, novo.text.length);
    final ateOCursor = soDigitos(novo.text.substring(0, fim)).length;
    var digitos = soDigitos(novo.text);
    if (digitos.length > limite) digitos = digitos.substring(0, limite);
    final texto = montar(digitos);
    final alvo = ateOCursor.clamp(0, digitos.length);
    var cursor = alvo == 0 ? 0 : texto.length;
    if (alvo > 0) {
      var vistos = 0;
      for (var i = 0; i < texto.length; i++) {
        final codigo = texto.codeUnitAt(i);
        if (codigo >= 48 && codigo <= 57) {
          vistos++;
          if (vistos == alvo) {
            cursor = i + 1;
            break;
          }
        }
      }
    }
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
