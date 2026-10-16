from datetime import date, datetime

from .database import db


# cada entrada de mercadoria vira um lote, com quantidade, validade e custo proprios.
# o estoque do produto e a soma dos lotes (ver services/estoque_lote_service.py)
class Lote(db.Model):
    __tablename__ = "lote"

    # de onde o lote veio
    ORIGENS = {
        "entrada": "Entrada",
        "inicial": "Estoque inicial",
        "ajuste": "Ajuste",
        "importacao": "Importação",
        "erp": "ERP",
    }

    id_lote = db.Column(db.Integer, primary_key=True)
    id_produto = db.Column(db.Integer, db.ForeignKey("produto.id_produto"), nullable=False)
    codigo_lote = db.Column(db.String(50))
    data_entrada = db.Column(db.Date, nullable=False, default=date.today)
    data_validade = db.Column(db.Date)
    quantidade_inicial = db.Column(db.Integer, nullable=False)
    quantidade_atual = db.Column(db.Integer, nullable=False)
    custo_unitario = db.Column(db.Numeric(10, 2))
    origem = db.Column(db.String(20), nullable=False, default="entrada")
    id_usuario = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))
    criado_em = db.Column(db.DateTime, default=datetime.now)

    # produto.lotes: os lotes do produto (apagar o produto apaga os lotes junto)
    produto = db.relationship("Produto", backref=db.backref("lotes", cascade="all, delete-orphan"))
    usuario = db.relationship("Usuario")

    @staticmethod
    def buscar_por_id(id):
        return db.session.get(Lote, id)

    # "Lote L-12" (com codigo) ou "Lote #3"
    def titulo(self):
        return ("Lote " + self.codigo_lote) if self.codigo_lote else ("Lote #" + str(self.id_lote))

    def dias_para_vencer(self):
        if not self.data_validade:
            return None
        return (self.data_validade - date.today()).days

    def virar_dict(self):
        dias = self.dias_para_vencer()
        return {
            "id_lote": self.id_lote,
            "titulo": self.titulo(),
            "id_produto": self.id_produto,
            "produto_nome": self.produto.nome if self.produto else None,
            "unidade": self.produto.unidade if self.produto else None,
            "codigo_lote": self.codigo_lote,
            "data_entrada": self.data_entrada.isoformat() if self.data_entrada else None,
            "data_validade": self.data_validade.isoformat() if self.data_validade else None,
            "dias_para_vencer": dias,
            "vencido": dias is not None and dias < 0,
            "quantidade_inicial": self.quantidade_inicial,
            "quantidade_atual": self.quantidade_atual,
            "custo_unitario": float(self.custo_unitario) if self.custo_unitario is not None else None,
            "origem": self.origem,
            "usuario": self.usuario.nome if self.usuario else None,
        }
