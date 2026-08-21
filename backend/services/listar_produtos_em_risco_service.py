from repositories.produto_repository import ProdutoRepository


# RF06 - produto chegando no minimo = risco de faltar na prateleira
class ListarProdutosEmRiscoService:

    def __init__(self):
        self.repo = ProdutoRepository()

    def executar(self):
        return [p.virar_dict() for p in self.repo.listar_em_risco_de_ruptura()]
