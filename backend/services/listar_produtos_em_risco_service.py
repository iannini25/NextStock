from models.produto_model import Produto
from repositories.produto_repository import ProdutoRepository
from services.prever_demanda_service import PreverDemandaService


# RF06 - minimo atingido ou demanda prevista (com clima) maior que o estoque
class ListarProdutosEmRiscoService:

    def __init__(self):
        self.repo = ProdutoRepository()

    def executar(self):
        vistos = {}
        for p in self.repo.listar_em_risco_de_ruptura():
            d = p.virar_dict()
            d["motivo"] = "estoque no mínimo"
            vistos[p.id_produto] = d

        for prev in PreverDemandaService().executar(7, "auto"):
            if prev["previsao_demanda"] <= prev["estoque_atual"]:
                continue
            motivo = (
                "demanda prevista ("
                + str(prev["previsao_demanda"])
                + ") maior que o estoque ("
                + str(prev["estoque_atual"])
                + ") nos próximos 7 dias"
            )
            if prev["id_produto"] in vistos:
                vistos[prev["id_produto"]]["motivo"] = "estoque no mínimo e " + motivo
                continue
            produto = Produto.buscar_por_id(prev["id_produto"])
            if not produto:
                continue
            d = produto.virar_dict()
            d["motivo"] = motivo
            vistos[produto.id_produto] = d
        return list(vistos.values())
