from .database import db


class Produto(db.Model):
    __tablename__ = "produto"

    id_produto = db.Column(db.Integer, primary_key=True)
    id_categoria = db.Column(db.Integer, db.ForeignKey("categoria.id_categoria"))
    nome = db.Column(db.String(150), nullable=False)
    codigo_barras = db.Column(db.String(50), unique=True)
    preco_custo = db.Column(db.Numeric(10, 2))
    preco_venda = db.Column(db.Numeric(10, 2), nullable=False)
    quantidade_estoque = db.Column(db.Integer, default=0)
    unidade = db.Column(db.String(10), default="UN")
    data_validade = db.Column(db.Date)

    categoria = db.relationship("Categoria")

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    # atualiza tudo de uma vez (a tela sempre manda o form inteiro)
    def editar(self, nome, id_categoria, codigo, custo, venda, qtd, unidade, validade):
        self.nome = nome
        self.id_categoria = id_categoria
        self.codigo_barras = codigo
        self.preco_custo = custo
        self.preco_venda = venda
        self.quantidade_estoque = qtd
        self.unidade = unidade
        self.data_validade = validade
        db.session.commit()

    def apagar(self):
        db.session.delete(self)
        db.session.commit()

    @staticmethod
    def pegarTodos():
        return Produto.query.all()

    @staticmethod
    def pegarPorId(id):
        return Produto.query.get(id)

    @staticmethod
    def pegarPorCodigo(cod):
        return Produto.query.filter_by(codigo_barras=cod).first()

    def virarDict(self):
        return {
            "id_produto": self.id_produto,
            "id_categoria": self.id_categoria,
            "categoria_nome": self.categoria.nome if self.categoria else None,
            "nome": self.nome,
            "codigo_barras": self.codigo_barras,
            "preco_custo": float(self.preco_custo) if self.preco_custo is not None else None,
            "preco_venda": float(self.preco_venda) if self.preco_venda is not None else None,
            "quantidade_estoque": self.quantidade_estoque,
            "unidade": self.unidade,
            "data_validade": self.data_validade.isoformat() if self.data_validade else None,
        }
