import math

from models.produto_model import Produto
from services.prever_demanda_service import PreverDemandaService


class SugerirComprasService:

    def executar(self, dias, clima):
        previsoes = PreverDemandaService().executar(dias, clima)
        lista = []
        for previsao in previsoes:
            produto = Produto.buscar_por_id(previsao["id_produto"])
            if not produto:
                continue
            estoque = previsao["estoque_atual"]
            minimo = produto.estoque_minimo or 0
            demanda = previsao["previsao_demanda"]
            quantidade = demanda + minimo - estoque
            if quantidade <= 0:
                continue
            quantidade = math.ceil(quantidade)
            custo = float(produto.preco_custo or 0)
            lista.append({
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "unidade": produto.unidade,
                "estoque_atual": estoque,
                "estoque_minimo": minimo,
                "previsao_demanda": demanda,
                "quantidade_sugerida": quantidade,
                "preco_custo": custo if produto.preco_custo is not None else None,
                "custo_estimado": round(quantidade * custo, 2),
            })
        lista.sort(key=lambda s: s["quantidade_sugerida"], reverse=True)
        return lista
