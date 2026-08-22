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

class ResultadoClima {
  String cidade;
  String fonte;
  String? aviso;
  List<ClimaDia> dias;

  ResultadoClima({
    required this.cidade,
    required this.fonte,
    this.aviso,
    required this.dias,
  });

  factory ResultadoClima.fromJson(Map<String, dynamic> j) {
    final dias = (j['dias'] as List? ?? [])
        .map((e) => ClimaDia.fromJson(e as Map<String, dynamic>))
        .toList();
    return ResultadoClima(
      cidade: j['cidade'] ?? '',
      fonte: j['fonte'] ?? '',
      aviso: j['aviso'] as String?,
      dias: dias,
    );
  }
}
