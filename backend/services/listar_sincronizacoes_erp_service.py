from repositories.sincronizacao_erp_repository import SincronizacaoErpRepository


class ListarSincronizacoesErpService:

    def __init__(self, repo=None):
        self.repo = repo if repo is not None else SincronizacaoErpRepository()

    # as mais recentes primeiro
    def executar(self, limite=20):
        return [s.virar_dict() for s in self.repo.listar_recentes(limite)]
