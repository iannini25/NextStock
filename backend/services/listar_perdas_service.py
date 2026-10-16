from datetime import datetime, timedelta

from models.perda_model import Perda
from services.utils import virar_data


class ListarPerdasService:

    # filtros (opcionais): inicio e fim (aaaa-mm-dd, inclusive), motivo, tipo e id_produto. mais recente primeiro
    def executar(self, filtros):
        inicio = virar_data(filtros.get("inicio"))
        fim = virar_data(filtros.get("fim"))
        if inicio and fim and inicio > fim:
            raise ValueError("a data de início tem que ser antes da data de fim")
        motivo = (filtros.get("motivo") or "").strip() or None
        if motivo and motivo not in Perda.MOTIVOS:
            raise ValueError("motivo inválido. use: " + ", ".join(Perda.MOTIVOS))
        tipo = (filtros.get("tipo") or "").strip() or None
        if tipo and tipo not in Perda.TIPOS:
            raise ValueError("tipo tem que ser perda ou descarte")
        id_produto = filtros.get("id_produto")
        if id_produto not in (None, ""):
            try:
                id_produto = int(id_produto)
            except (TypeError, ValueError):
                raise ValueError("id_produto tem que ser número")
        else:
            id_produto = None

        q = Perda.query
        if inicio:
            q = q.filter(Perda.data_registro >= datetime.combine(inicio, datetime.min.time()))
        if fim:
            q = q.filter(Perda.data_registro < datetime.combine(fim + timedelta(days=1), datetime.min.time()))
        if motivo:
            q = q.filter(Perda.motivo == motivo)
        if tipo:
            q = q.filter(Perda.tipo == tipo)
        if id_produto:
            q = q.filter(Perda.id_produto == id_produto)
        perdas = q.order_by(Perda.data_registro.desc(), Perda.id_perda.desc()).all()
        return {
            "itens": [p.virar_dict() for p in perdas],
            "valor_total": round(sum(float(p.valor_total or 0) for p in perdas), 2),
            "quantidade_total": sum(p.quantidade for p in perdas),
        }
