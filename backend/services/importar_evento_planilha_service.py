from services.formato_planilha import _texto, _numero, _data
from services.utils import inteiro
from models.evento_model import Evento


class ImportarEventoPlanilhaService:

    def executar(self, item):
        nome = _texto(item.get("nome"))
        if not nome:
            raise ValueError("nome é obrigatório")
        data_inicio = _data(item.get("data_inicio"))
        data_fim = _data(item.get("data_fim"))
        if not data_inicio or not data_fim:
            raise ValueError("data_inicio e data_fim são obrigatórias")
        if data_fim < data_inicio:
            raise ValueError("data_fim tem que ser depois da data_inicio")
        try:
            impacto = int(_texto(item.get("impacto_percentual")) or 0)
        except ValueError:
            raise ValueError("impacto_percentual tem que ser número inteiro")
        Evento(
            nome=nome,
            data_inicio=data_inicio,
            data_fim=data_fim,
            impacto_percentual=impacto,
        ).salvar()
        return "ok"
