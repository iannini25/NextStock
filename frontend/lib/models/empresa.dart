class Empresa {
  int? id;
  String nome; // razao social
  String? nomeFantasia;
  String? cnpj; // so os 14 numeros
  String? email;
  String? telefone;

  Empresa({
    this.id,
    required this.nome,
    this.nomeFantasia,
    this.cnpj,
    this.email,
    this.telefone,
  });

  factory Empresa.fromJson(Map<String, dynamic> j) {
    return Empresa(
      id: j['id_empresa'],
      nome: j['nome'] ?? '',
      nomeFantasia: j['nome_fantasia'],
      cnpj: j['cnpj'],
      email: j['email'],
      telefone: j['telefone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'nome_fantasia': nomeFantasia,
      'cnpj': cnpj,
      'email': email,
      'telefone': telefone,
    };
  }
}
