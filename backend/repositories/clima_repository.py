from datetime import datetime

from models.database import db
from models.clima_model import ClimaDia


class ClimaRepository:

    def listar_no_periodo(self, inicio, fim):
        return (
            ClimaDia.query
            .filter(ClimaDia.data >= inicio)
            .filter(ClimaDia.data <= fim)
            .order_by(ClimaDia.data.asc())
            .all()
        )

    def buscar_por_data(self, data):
        return ClimaDia.buscar_por_data(data)

    def salvar_varios(self, registros):
        agora = datetime.now()
        for r in registros:
            row = ClimaDia.buscar_por_data(r["data"])
            if row:
                row.temperatura = r["temperatura"]
                row.chuva_mm = r["chuva_mm"]
                row.condicao = r["condicao"]
                row.atualizado_em = agora
            else:
                db.session.add(ClimaDia(
                    data=r["data"],
                    temperatura=r["temperatura"],
                    chuva_mm=r["chuva_mm"],
                    condicao=r["condicao"],
                    atualizado_em=agora,
                ))
        db.session.commit()
