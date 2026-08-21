from datetime import date, timedelta

from models.produto_model import Produto


# aqui ficam as consultas que fogem do CRUD simples (filtro por data, comparacao entre colunas).
# o service nao monta query, so pede pro repository.
class ProdutoRepository:

    # produtos que vencem de hoje ate daqui a X dias (nao traz o que ja venceu ha muito tempo? traz sim,
    # produto vencido tambem precisa aparecer pro lojista tirar da prateleira)
    def listar_proximos_do_vencimento(self, dias):
        limite = date.today() + timedelta(days=dias)
        return (
            Produto.query
            .filter(Produto.data_validade.isnot(None))
            .filter(Produto.data_validade <= limite)
            .order_by(Produto.data_validade.asc())
            .all()
        )

    # estoque atual <= estoque minimo = risco de acabar o produto
    def listar_em_risco_de_ruptura(self):
        return (
            Produto.query
            .filter(Produto.estoque_minimo > 0)
            .filter(Produto.quantidade_estoque <= Produto.estoque_minimo)
            .order_by(Produto.quantidade_estoque.asc())
            .all()
        )

    def listar_vencidos(self):
        return (
            Produto.query
            .filter(Produto.data_validade.isnot(None))
            .filter(Produto.data_validade < date.today())
            .order_by(Produto.data_validade.asc())
            .all()
        )
