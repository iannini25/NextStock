from datetime import datetime, time

from models.leitura_temperatura_model import LeituraTemperatura
from models.local_armazenamento_model import LocalArmazenamento
from services.utils import inteiro, virar_data


# historico de leituras de um local, da mais nova pra mais antiga
class ListarLeiturasService:

    def executar(self, id_local, filtros):
        local = LocalArmazenamento.buscar_por_id(id_local)
        if not local:
            return None
        inicio = virar_data(filtros.get("inicio"))
        fim = virar_data(filtros.get("fim"))
        limite = inteiro(filtros.get("limite"))
        limite = 100 if limite is None else limite
        if limite < 1 or limite > 1000:
            raise ValueError("limite tem que ser entre 1 e 1000")

        consulta = LeituraTemperatura.query.filter_by(id_local=id_local)
        if inicio:
            consulta = consulta.filter(LeituraTemperatura.data_hora >= datetime.combine(inicio, time.min))
        if fim:
            consulta = consulta.filter(LeituraTemperatura.data_hora <= datetime.combine(fim, time.max))
        leituras = (consulta.order_by(LeituraTemperatura.data_hora.desc(), LeituraTemperatura.id_leitura.desc())
                    .limit(limite).all())
        return [l.virar_dict() for l in leituras]
