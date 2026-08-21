from repositories.produto_repository import ProdutoRepository


# RF03 - avisa o que ta perto de vencer pra dar tempo de promover/tirar da prateleira
class ListarProdutosVencendoService:

    def __init__(self):
        self.repo = ProdutoRepository()

    def executar(self, dias):
        # se vier lixo no parametro usa 7 dias
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 7
        if dias < 0 or dias > 365:
            raise ValueError("dias tem que ser entre 0 e 365")

        return [p.virar_dict() for p in self.repo.listar_proximos_do_vencimento(dias)]
