from .database import db


class Venda(db.Model):
    __tablename__ = "venda"

    id_venda = db.Column(db.Integer, primary_key=True)
    id_produto = db.Column(db.Integer, db.ForeignKey("produto.id_produto"), nullable=False)
    quantidade = db.Column(db.Integer, nullable=False)
    data_venda = db.Column(db.Date, nullable=False)

    produto = db.relationship("Produto")

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    @staticmethod
    def listar_todos():
        return Venda.query.all()

    @staticmethod
    def buscar_por_id(id):
        return Venda.query.get(id)

    def virar_dict(self):
        valor_total = None
        if self.produto and self.produto.preco_venda is not None:
            valor_total = float(self.quantidade * self.produto.preco_venda)
        return {
            "id_venda": self.id_venda,
            "id_produto": self.id_produto,
            "produto_nome": self.produto.nome if self.produto else None,
            "quantidade": self.quantidade,
            "valor_total": valor_total,
            "data_venda": self.data_venda.isoformat() if self.data_venda else None,
        }
