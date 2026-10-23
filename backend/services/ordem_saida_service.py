from services.listar_lotes_produto_service import ListarLotesProdutoService


# lotes com saldo ja na ordem de saida, cada um com a posicao na fila e o selo "vender primeiro"
# (o primeiro lote que ainda esta na validade; vencido e pra retirar, nunca pra vender primeiro)
def lotes_na_ordem_de_saida(produto):
    return ListarLotesProdutoService().montar_ordem(produto)


class OrdemSaidaService:

    def __init__(self, listagem=None):
        self.listagem = listagem if listagem is not None else ListarLotesProdutoService()

    def executar(self, id_produto):
        return self.listagem.executar(id_produto)
