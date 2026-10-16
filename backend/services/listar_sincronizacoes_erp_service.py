from models.sincronizacao_erp_model import SincronizacaoErp


class ListarSincronizacoesErpService:

    # as mais recentes primeiro
    def executar(self, limite=20):
        return [s.virar_dict() for s in SincronizacaoErp.listar_recentes(limite)]
