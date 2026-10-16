from datetime import datetime

from .database import db


# lugar onde a mercadoria fica guardada (geladeira, freezer, deposito...) com a faixa de temperatura certa.
# nao e apagado, so desativado: as leituras antigas e os produtos continuam ligados a ele
class LocalArmazenamento(db.Model):
    __tablename__ = "local_armazenamento"

    TIPOS = {"ambiente": "Ambiente", "refrigerado": "Refrigerado", "congelado": "Congelado"}
    # faixa sugerida pra cada tipo (o app preenche quando escolhe o tipo)
    FAIXAS_PADRAO = {"ambiente": (15.0, 30.0), "refrigerado": (0.0, 5.0), "congelado": (-25.0, -18.0)}

    id_local = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(100), nullable=False, unique=True)
    tipo = db.Column(db.String(20), nullable=False, default="refrigerado")
    temp_min = db.Column(db.Numeric(5, 1), nullable=False)
    temp_max = db.Column(db.Numeric(5, 1), nullable=False)
    ativo = db.Column(db.Boolean, nullable=False, default=True)
    criado_em = db.Column(db.DateTime, default=datetime.now)

    @staticmethod
    def buscar_por_id(id):
        return db.session.get(LocalArmazenamento, id)

    @staticmethod
    def buscar_por_nome(nome):
        return LocalArmazenamento.query.filter(db.func.lower(LocalArmazenamento.nome) == nome.lower()).first()

    @staticmethod
    def listar(todos=False):
        consulta = LocalArmazenamento.query
        if not todos:
            consulta = consulta.filter_by(ativo=True)
        return consulta.order_by(LocalArmazenamento.nome).all()

    def dentro_da_faixa(self, temperatura):
        return float(self.temp_min) <= float(temperatura) <= float(self.temp_max)

    def virar_dict(self):
        return {
            "id_local": self.id_local,
            "nome": self.nome,
            "tipo": self.tipo,
            "nome_tipo": self.TIPOS.get(self.tipo, self.tipo),
            "temp_min": float(self.temp_min),
            "temp_max": float(self.temp_max),
            "ativo": self.ativo,
        }
