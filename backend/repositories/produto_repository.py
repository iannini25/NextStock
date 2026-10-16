from datetime import date, timedelta

from sqlalchemy import or_

from models.produto_model import Produto


# o que a pessoa digita vira texto literal na busca (% e _ nao viram coringa do LIKE)
def _padrao_like(texto):
    escapado = texto.replace("/", "//").replace("%", "/%").replace("_", "/_")
    return "%" + escapado + "%"


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

    # filtros da tela de produtos; todos opcionais e combinaveis
    def buscar_com_filtros(self, busca=None, id_categoria=None, situacao=None):
        q = Produto.query
        if busca:
            padrao = _padrao_like(busca)
            q = q.filter(or_(
                Produto.nome.ilike(padrao, escape="/"),
                Produto.codigo_barras.ilike(padrao, escape="/"),
            ))
        if id_categoria:
            q = q.filter(Produto.id_categoria == id_categoria)

        hoje = date.today()
        if situacao == "baixo_estoque":  # mesma regra do risco de ruptura
            q = q.filter(Produto.estoque_minimo > 0, Produto.quantidade_estoque <= Produto.estoque_minimo)
        elif situacao == "sem_estoque":
            q = q.filter(or_(Produto.quantidade_estoque.is_(None), Produto.quantidade_estoque <= 0))
        elif situacao == "vencendo":  # vence de hoje ate daqui a 7 dias (os ja vencidos ficam no outro filtro)
            q = q.filter(Produto.data_validade >= hoje, Produto.data_validade <= hoje + timedelta(days=7))
        elif situacao == "vencido":
            q = q.filter(Produto.data_validade < hoje)

        return q.order_by(Produto.nome).all()

    def listar_vencidos(self):
        return (
            Produto.query
            .filter(Produto.data_validade.isnot(None))
            .filter(Produto.data_validade < date.today())
            .order_by(Produto.data_validade.asc())
            .all()
        )
