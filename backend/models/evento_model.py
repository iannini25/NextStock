from .database import db


class Evento(db.Model):
    __tablename__ = "evento"

    id_evento = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(100), nullable=False)
    data_inicio = db.Column(db.Date, nullable=False)
    data_fim = db.Column(db.Date, nullable=False)
    impacto_percentual = db.Column(db.Integer, default=0)

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    def deletar(self):
        db.session.delete(self)
        db.session.commit()

    @staticmethod
    def listar_todos():
        return Evento.query.order_by(Evento.data_inicio).all()

    @staticmethod
    def buscar_por_id(id):
        return Evento.query.get(id)

    def virar_dict(self):
        return {
            "id_evento": self.id_evento,
            "nome": self.nome,
            "data_inicio": self.data_inicio.isoformat() if self.data_inicio else None,
            "data_fim": self.data_fim.isoformat() if self.data_fim else None,
            "impacto_percentual": self.impacto_percentual,
        }
