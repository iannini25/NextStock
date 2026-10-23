from datetime import date

from models.lote_model import Lote
from models.produto_model import Produto
from services.planejar_saida_service import PlanejarSaidaService


# antes de registrar a venda: de quais lotes ela vai sair e quanto de cada. nao grava nada.
# usa a mesma conta da baixa de verdade (planejar_saida), entao o que a previa mostra e o que acontece
class PreviaVendaService:

    def __init__(self, produto_model=None, planejador=None, hoje=None):
        self.produto_model = produto_model if produto_model is not None else Produto
        self.planejador = planejador if planejador is not None else PlanejarSaidaService()
        self.hoje = hoje if hoje is not None else date.today

    def executar(self, id_produto, quantidade):
        produto = self.produto_model.buscar_por_id(id_produto) if id_produto else None
        if not produto:
            raise ValueError("produto não existe")
        quantidade = PlanejarSaidaService.validar_quantidade(quantidade)

        hoje = self.hoje()
        lotes = list(produto.lotes)
        if not lotes and (produto.quantidade_estoque or 0) > 0:
            # Simula o lote que a baixa criará; sem sessão, INSERT ou movimentação.
            lotes = [Lote(origem="inicial", data_entrada=hoje, data_validade=produto.data_validade,
                          quantidade_atual=produto.quantidade_estoque)]

        plano, falta = self.planejador.executar(lotes, quantidade, hoje=hoje)
        saidas = [lote.saida(sai, hoje) for lote, sai in plano]
        aviso = None
        if any(s["vencido"] for s in saidas):
            aviso = "parte da venda sairia de lote vencido: confira se esse produto ainda está bom pra vender"
        return {
            "id_produto": produto.id_produto,
            "quantidade": quantidade,
            "suficiente": falta == 0,
            "falta": falta,
            "lotes": saidas,
            "aviso": aviso,
        }


# o que sai de um lote (mesmo formato na previa e no "lotes_consumidos" da venda)
def saida_do_lote(lote, quantidade):
    return lote.saida(quantidade)
