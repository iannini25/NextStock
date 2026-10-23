from services.importar_produto_erp_service import ImportarProdutoErpService
from services.importar_venda_erp_service import ImportarVendaErpService


class ImportarErpService:

    # modo "importacao" (padrao, usado pelo POST /erp/importar): igual sempre foi.
    # modo "sincronizacao" (quando o NextStock busca os dados no ERP):
    #   - o ERP manda o estoque atual, entao as vendas entram so como historico (nao baixam de novo)
    #   - campo que o ERP nao manda fica como esta no NextStock (ex.: estoque_minimo, validade)
    #   - cada venda precisa de id_externo e nunca entra duas vezes
    def __init__(self, modo="importacao", produtos=None, vendas=None):
        self.sincronizando = modo == "sincronizacao"
        self.produtos = produtos if produtos is not None else ImportarProdutoErpService(self.sincronizando)
        self.vendas = vendas if vendas is not None else ImportarVendaErpService(self.sincronizando)

    def executar(self, dados):
        if not isinstance(dados, dict):
            raise ValueError("os dados precisam ser um objeto JSON")
        produtos = dados.get("produtos") or []
        vendas = dados.get("vendas") or []
        if not produtos and not vendas:
            raise ValueError("manda pelo menos produtos ou vendas")
        return self.importar(produtos, vendas)

    # na sincronizacao pode vir tudo vazio (nada mudou no ERP desde a ultima vez)
    def importar(self, produtos, vendas):
        if not isinstance(produtos, list) or not isinstance(vendas, list):
            raise ValueError("produtos e vendas precisam ser listas")
        criados = 0
        atualizados = 0
        importadas = 0
        repetidas = 0
        erros = []

        for item in produtos:
            try:
                resultado = self.importar_produto(item)
                if resultado == "criado":
                    criados += 1
                else:
                    atualizados += 1
            except ValueError as e:
                erros.append("produto " + self.identificar(item, "codigo_barras") + ": " + str(e))

        for item in vendas:
            try:
                if self.importar_venda(item) == "repetida":
                    repetidas += 1
                else:
                    importadas += 1
            except ValueError as e:
                chave = "id_externo" if self.sincronizando else "codigo_barras"
                erros.append("venda " + self.identificar(item, chave) + ": " + str(e))

        resultado = {
            "produtos_criados": criados,
            "produtos_atualizados": atualizados,
            "vendas_importadas": importadas,
            "erros": erros,
        }
        if self.sincronizando:
            resultado["vendas_ja_importadas"] = repetidas
        return resultado

    @staticmethod
    def identificar(item, chave):
        return str(item.get(chave)) if isinstance(item, dict) else "?"

    def importar_produto(self, item):
        return self.produtos.executar(item)

    def importar_venda(self, item):
        return self.vendas.executar(item)
