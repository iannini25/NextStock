class MensagemChat {
  String papel;
  String texto;

  MensagemChat({required this.papel, required this.texto});

  Map<String, dynamic> toJson() {
    return {'papel': papel, 'texto': texto};
  }
}
