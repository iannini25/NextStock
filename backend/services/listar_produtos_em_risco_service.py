from models.produto_model import Produto
from repositories.produto_repository import ProdutoRepository
from services.prever_demanda_service import PreverDemandaService
from services.classificar_curva_abc_service import ClassificarCurvaAbcService
from services.alertas_excesso_service import prioridade_da_falta


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

        # campos novos (Etapa 12): classe ABC e prioridade da falta. o resto continua igual
        classes = ClassificarCurvaAbcService().classes() if vistos else {}
        for id_produto, d in vistos.items():
            d["classe_abc"] = classes.get(id_produto, "C")
            d["prioridade"] = prioridade_da_falta(d["classe_abc"], d["quantidade_estoque"] or 0)
        return list(vistos.values())
