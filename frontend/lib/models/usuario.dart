class Usuario {
  int? id;
  String nome;
  String email;
  String perfil; // 'admin' ou 'usuario'
  bool ativo;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    this.perfil = 'usuario',
    this.ativo = true,
  });

  bool get ehAdmin => perfil == 'admin';

  String get nomePerfil => ehAdmin ? 'Administrador' : 'Usuário';

  factory Usuario.fromJson(Map<String, dynamic> j) {
    return Usuario(
      id: j['id_usuario'],
      nome: j['nome'] ?? '',
      email: j['email'] ?? '',
      perfil: j['perfil'] ?? 'usuario',
      ativo: j['ativo'] ?? true,
    );
  }

  // a senha nao fica no modelo: vai separada so quando for criar ou trocar
  Map<String, dynamic> toJson({String? senha}) {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'ativo': ativo,
      'senha': ?senha,
    };
  }
}
