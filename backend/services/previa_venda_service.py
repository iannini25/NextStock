from models.produto_model import Produto
from services.estoque_lote_service import planejar_saida
from services.utils import inteiro


# antes de registrar a venda: de quais lotes ela vai sair e quanto de cada. nao grava nada.
# usa a mesma conta da baixa de verdade (planejar_saida), entao o que a previa mostra e o que acontece
class PreviaVendaService:

    def executar(self, id_produto, quantidade):
        produto = Produto.buscar_por_id(id_produto) if id_produto else None
        if not produto:
            raise ValueError("produto não existe")
        quantidade = inteiro(quantidade)
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")

        lotes = list(produto.lotes)
        if not lotes and (produto.quantidade_estoque or 0) > 0:
            # dado antigo sem lote: a venda sairia do "estoque inicial" que a baixa cria na hora
            return {
                "id_produto": produto.id_produto,
                "quantidade": quantidade,
                "suficiente": quantidade <= produto.quantidade_estoque,
                "falta": max(quantidade - produto.quantidade_estoque, 0),
                "lotes": [{"id_lote": None, "titulo": "Estoque inicial", "quantidade": min(quantidade, produto.quantidade_estoque),
                           "data_validade": produto.data_validade.isoformat() if produto.data_validade else None,
                           "dias_para_vencer": None, "vencido": False}],
                "aviso": None,
            }

        plano, falta = planejar_saida(lotes, quantidade)
        saidas = [saida_do_lote(lote, sai) for lote, sai in plano]
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
    dias = lote.dias_para_vencer()
    return {
        "id_lote": lote.id_lote,
        "titulo": lote.titulo(),
        "quantidade": quantidade,
        "data_validade": lote.data_validade.isoformat() if lote.data_validade else None,
        "dias_para_vencer": dias,
        "vencido": dias is not None and dias < 0,
    }
