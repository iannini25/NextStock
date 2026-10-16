from models.produto_model import Produto
from repositories.produto_repository import ProdutoRepository
from services.utils import virar_texto

SITUACOES = ("baixo_estoque", "sem_estoque", "vencendo", "vencido")


class ListarProdutosService:

    # filtros (todos opcionais): busca (nome ou codigo de barras), id_categoria e situacao.
    # sem filtro nenhum devolve a lista completa, igual era antes.
    def executar(self, filtros=None):
        filtros = filtros or {}
        busca = virar_texto(filtros.get("busca"), "busca", 100)

        id_categoria = filtros.get("id_categoria")
        if id_categoria in (None, ""):
            id_categoria = None
        else:
            try:
                id_categoria = int(id_categoria)
            except (TypeError, ValueError):
                raise ValueError("id_categoria tem que ser número")

        situacao = str(filtros.get("situacao") or "").strip().lower() or None
        if situacao and situacao not in SITUACOES:
            raise ValueError("situação inválida. use: " + ", ".join(SITUACOES))

        if not (busca or id_categoria or situacao):
            return [p.virar_dict() for p in Produto.listar_todos()]
        produtos = ProdutoRepository().buscar_com_filtros(busca, id_categoria, situacao)
        return [p.virar_dict() for p in produtos]
