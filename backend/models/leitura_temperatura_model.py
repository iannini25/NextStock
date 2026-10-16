from datetime import datetime

from .database import db


# uma medida de temperatura de um local: lancada na tela (manual) ou enviada por um dispositivo (sensor)
class LeituraTemperatura(db.Model):
    __tablename__ = "leitura_temperatura"

    ORIGENS = {"manual": "Manual", "sensor": "Sensor"}

    id_leitura = db.Column(db.Integer, primary_key=True)
    id_local = db.Column(db.Integer, db.ForeignKey("local_armazenamento.id_local"), nullable=False)
    temperatura = db.Column(db.Numeric(5, 1), nullable=False)
    umidade = db.Column(db.Numeric(5, 1))
    data_hora = db.Column(db.DateTime, nullable=False, default=datetime.now)
    origem = db.Column(db.String(10), nullable=False, default="manual")
    id_usuario = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))

    local = db.relationship("LocalArmazenamento")
    usuario = db.relationship("Usuario")

    # a mais recente do local (None se nunca teve leitura)
    @staticmethod
    def ultima_do_local(id_local):
        return (LeituraTemperatura.query.filter_by(id_local=id_local)
                .order_by(LeituraTemperatura.data_hora.desc(), LeituraTemperatura.id_leitura.desc()).first())

    def virar_dict(self):
        local = self.local
        return {
            "id_leitura": self.id_leitura,
            "id_local": self.id_local,
            "temperatura": float(self.temperatura),
            "umidade": float(self.umidade) if self.umidade is not None else None,
            "data_hora": self.data_hora.isoformat(timespec="seconds") if self.data_hora else None,
            "origem": self.origem,
            "nome_origem": self.ORIGENS.get(self.origem, self.origem),
            "usuario": self.usuario.nome if self.usuario else None,
            "fora_da_faixa": (not local.dentro_da_faixa(self.temperatura)) if local else None,
        }
