# falha ao falar com o ERP (fora do ar, chave recusada, resposta estranha...), ja com mensagem pra mostrar na tela
class ErroErp(Exception):
    pass


# o que todo conector de ERP precisa saber fazer. pra ligar um ERP de verdade (Bling, Omie...),
# basta criar outra classe com esses tres metodos e registrar em services/erp/fabrica.py
class ConectorErp:

    def __init__(self, url_base, chave):
        self.url_base = url_base.rstrip("/")
        self.chave = chave

    # confere se o ERP responde e aceita a chave; devolve o que o ERP mandou
    def testar_conexao(self):
        raise NotImplementedError

    # produtos que mudaram depois de `desde` (datetime ou None = todos), no formato do /erp/importar
    def buscar_produtos(self, desde):
        raise NotImplementedError

    # vendas registradas depois de `desde`; cada uma com id_externo
    def buscar_vendas(self, desde):
        raise NotImplementedError
