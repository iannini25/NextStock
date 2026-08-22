import 'produto.dart';

class ClimaDia {
  String data;
  double? temperatura;
  double? chuvaMm;
  String condicao;

  ClimaDia({
    required this.data,
    this.temperatura,
    this.chuvaMm,
    required this.condicao,
  });

  factory ClimaDia.fromJson(Map<String, dynamic> j) {
    return ClimaDia(
      data: j['data'] ?? '',
      temperatura: paraDouble(j['temperatura']),
      chuvaMm: paraDouble(j['chuva_mm']),
      condicao: j['condicao'] ?? 'normal',
    );
  }

  String nomeCondicao() {
    switch (condicao) {
      case 'chuva_forte':
        return 'chuva forte';
      case 'chuva':
        return 'chuva';
      case 'calor':
        return 'calor';
      case 'frio':
        return 'frio';
      default:
        return 'normal';
    }
  }

  String dataCurta() {
    final d = DateTime.tryParse(data);
    if (d == null) return data;
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }
}
