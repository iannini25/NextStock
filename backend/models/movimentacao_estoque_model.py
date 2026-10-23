from datetime import datetime

from .database import db


# registro de tudo que entra e sai do estoque (quanto, de qual lote, saldo depois, quem, quando, de onde).
# quem grava e o services/estoque_lote_service.py, entao nenhuma mudanca de estoque fica sem registro.
class MovimentacaoEstoque(db.Model):
    __tablename__ = "movimentacao_estoque"

    # tipo -> (nome pra mostrar, +1 entra / -1 sai)
    TIPOS = {
        "entrada": ("Entrada", 1),
        "saldo_inicial": ("Saldo inicial", 1),
        "venda": ("Venda", -1),
        "ajuste_entrada": ("Ajuste (entrada)", 1),
        "ajuste_saida": ("Ajuste (saída)", -1),
        "perda": ("Perda", -1),
        "descarte": ("Descarte", -1),
    }
    # de onde veio
    ORIGENS = {
        "manual": "Manual",
        "planilha": "Planilha",
        "erp": "ERP",
        "sistema": "Sistema",
        "historico": "Histórico",
    }

    id_movimentacao = db.Column(db.Integer, primary_key=True)
    id_produto = db.Column(db.Integer, db.ForeignKey("produto.id_produto"), nullable=False)
    id_lote = db.Column(db.Integer, db.ForeignKey("lote.id_lote"))
    tipo = db.Column(db.String(20), nullable=False)
    quantidade = db.Column(db.Integer, nullable=False)  # sempre positiva; o tipo diz se entrou ou saiu
    saldo_produto_apos = db.Column(db.Integer)  # vazio nos registros do historico antigo
    custo_unitario = db.Column(db.Numeric(10, 2))
    id_venda = db.Column(db.Integer, db.ForeignKey("venda.id_venda"))
    id_usuario = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))
    origem = db.Column(db.String(20), nullable=False, default="manual")
    observacao = db.Column(db.String(255))
    data_hora = db.Column(db.DateTime, nullable=False, default=datetime.now)

    # apagar o produto (so da quando nao tem venda) apaga o historico dele junto
    produto = db.relationship("Produto", backref=db.backref("movimentacoes", cascade="all, delete-orphan"))
    lote = db.relationship("Lote", backref=db.backref("movimentacoes", cascade="all, delete-orphan"))
    usuario = db.relationship("Usuario")

    def salvar(self, confirmar=True):
        db.session.add(self)
        if confirmar:
            db.session.commit()
        return self

    def virar_dict(self):
        nome, sinal = self.TIPOS.get(self.tipo, (self.tipo, 0))
        lote = self.lote.titulo() if self.lote else None
        return {
            "id_movimentacao": self.id_movimentacao,
            "id_produto": self.id_produto,
            "produto_nome": self.produto.nome if self.produto else None,
            "unidade": self.produto.unidade if self.produto else None,
            "id_lote": self.id_lote,
            "lote": lote,
            "tipo": self.tipo,
            "nome_tipo": nome,
            "sinal": sinal,
            "quantidade": self.quantidade,
            "saldo_produto_apos": self.saldo_produto_apos,
            "custo_unitario": float(self.custo_unitario) if self.custo_unitario is not None else None,
            "id_venda": self.id_venda,
            "usuario": self.usuario.nome if self.usuario else None,
            "origem": self.origem,
            "nome_origem": self.ORIGENS.get(self.origem, self.origem),
            "observacao": self.observacao,
            "data_hora": self.data_hora.isoformat(timespec="seconds") if self.data_hora else None,
        }
