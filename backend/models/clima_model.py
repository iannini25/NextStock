from datetime import datetime

from .database import db


class ClimaDia(db.Model):
    __tablename__ = "clima_dia"

    data = db.Column(db.Date, primary_key=True)
    temperatura = db.Column(db.Float)
    chuva_mm = db.Column(db.Float)
    condicao = db.Column(db.String(20), nullable=False)
    atualizado_em = db.Column(db.DateTime, default=datetime.now)

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    @staticmethod
    def listar_todos():
        return ClimaDia.query.order_by(ClimaDia.data).all()

    @staticmethod
    def buscar_por_data(data):
        return ClimaDia.query.get(data)

    def virar_dict(self):
        return {
            "data": self.data.isoformat() if self.data else None,
            "temperatura": round(self.temperatura, 1) if self.temperatura is not None else None,
            "chuva_mm": round(self.chuva_mm, 1) if self.chuva_mm is not None else None,
            "condicao": self.condicao,
        }
