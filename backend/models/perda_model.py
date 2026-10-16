from datetime import datetime

from .database import db


# perda ou descarte de mercadoria, sempre de um lote, com o valor perdido (quantidade x custo do lote)
class Perda(db.Model):
    __tablename__ = "perda"

    TIPOS = {"perda": "Perda", "descarte": "Descarte"}
    MOTIVOS = {
        "vencimento": "Vencimento",
        "avaria": "Avaria",
        "temperatura": "Temperatura",
        "furto": "Furto",
        "outro": "Outro",
    }

    id_perda = db.Column(db.Integer, primary_key=True)
    id_produto = db.Column(db.Integer, db.ForeignKey("produto.id_produto"), nullable=False)
    id_lote = db.Column(db.Integer, db.ForeignKey("lote.id_lote"), nullable=False)
    tipo = db.Column(db.String(10), nullable=False)
    motivo = db.Column(db.String(20), nullable=False)
    quantidade = db.Column(db.Integer, nullable=False)
    custo_unitario = db.Column(db.Numeric(10, 2))  # copia do custo do lote no momento (se mudar depois, a perda nao muda)
    valor_total = db.Column(db.Numeric(12, 2), nullable=False, default=0)
    observacao = db.Column(db.String(255))
    id_usuario = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))
    data_registro = db.Column(db.DateTime, nullable=False, default=datetime.now)
    id_movimentacao = db.Column(db.Integer, db.ForeignKey("movimentacao_estoque.id_movimentacao"))

    produto = db.relationship("Produto")
    lote = db.relationship("Lote")
    usuario = db.relationship("Usuario")
    movimentacao = db.relationship("MovimentacaoEstoque")

    def virar_dict(self):
        return {
            "id_perda": self.id_perda,
            "id_produto": self.id_produto,
            "produto_nome": self.produto.nome if self.produto else None,
            "unidade": self.produto.unidade if self.produto else None,
            "id_lote": self.id_lote,
            "lote": self.lote.titulo() if self.lote else None,
            "tipo": self.tipo,
            "nome_tipo": self.TIPOS.get(self.tipo, self.tipo),
            "motivo": self.motivo,
            "nome_motivo": self.MOTIVOS.get(self.motivo, self.motivo),
            "quantidade": self.quantidade,
            "custo_unitario": float(self.custo_unitario) if self.custo_unitario is not None else None,
            "valor_total": float(self.valor_total or 0),
            "observacao": self.observacao,
            "usuario": self.usuario.nome if self.usuario else None,
            "data_registro": self.data_registro.isoformat(timespec="seconds") if self.data_registro else None,
        }
