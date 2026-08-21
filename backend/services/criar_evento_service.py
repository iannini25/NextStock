from models.evento_model import Evento
from services.utils import virar_data


class CriarEventoService:

    def executar(self, dados):
        if not dados.get("nome"):
            raise ValueError("nome é obrigatório")

        data_inicio = virar_data(dados.get("data_inicio"))
        data_fim = virar_data(dados.get("data_fim"))
        if not data_inicio or not data_fim:
            raise ValueError("data inicio e data fim são obrigatórias")
        if data_fim < data_inicio:
            raise ValueError("data fim tem que ser depois da data inicio")

        try:
            impacto = int(dados.get("impacto_percentual") or 0)
        except (TypeError, ValueError):
            raise ValueError("impacto tem que ser numero inteiro")

        evento = Evento(
            nome=dados["nome"],
            data_inicio=data_inicio,
            data_fim=data_fim,
            impacto_percentual=impacto,
        )
        evento.salvar()
        return evento.virar_dict()
