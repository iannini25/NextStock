from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService, ordenar_lotes_para_saida


# lotes com saldo ja na ordem de saida, cada um com a posicao na fila e o selo "vender primeiro"
# (o primeiro lote que ainda esta na validade; vencido e pra retirar, nunca pra vender primeiro)
def lotes_na_ordem_de_saida(produto):
    ordenados = ordenar_lotes_para_saida([l for l in produto.lotes if l.quantidade_atual > 0])
    primeiro_bom = next((l for l in ordenados if not (l.dias_para_vencer() is not None and l.dias_para_vencer() < 0)), None)
    resultado = []
    for posicao, lote in enumerate(ordenados, start=1):
        dados = lote.virar_dict()
        dados["posicao_saida"] = posicao
        dados["vender_primeiro"] = lote is primeiro_bom
        resultado.append(dados)
    return resultado


class OrdemSaidaService:

    def executar(self, id_produto):
        produto = Produto.buscar_por_id(id_produto)
        if not produto:
            return None
        if (produto.quantidade_estoque or 0) > 0 and not produto.lotes:  # dado antigo: cria o estoque inicial
            EstoqueLoteService(origem_movimento="sistema").garantir_lote_inicial(produto)
            db.session.commit()
        return {"produto": produto.virar_dict(), "lotes": lotes_na_ordem_de_saida(produto)}
