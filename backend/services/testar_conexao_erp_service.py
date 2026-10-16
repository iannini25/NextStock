from services.erp import fabrica


# confere se o ERP responde e aceita a chave (usa a configuracao salva, mesmo com a integracao desligada)
class TestarConexaoErpService:

    def executar(self):
        conector, _ = fabrica.criar_conector()
        detalhes = conector.testar_conexao()  # ErroErp sobe com a mensagem pra tela
        return {"ok": True, "mensagem": "Conexão com o ERP funcionando", "detalhes": detalhes}
