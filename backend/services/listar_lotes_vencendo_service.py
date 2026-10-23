from repositories.lote_repository import LoteRepository


# lotes com saldo que vencem nos proximos X dias (inclui os vencidos)
class ListarLotesVencendoService:

    def __init__(self, repo=None):
        self.repo = repo if repo is not None else LoteRepository()

    def executar(self, dias):
        if dias is None or dias == "":
            dias = 7
        try:
            if isinstance(dias, (bool, float)):
                raise ValueError
            dias = int(dias)
        except (TypeError, ValueError):
            raise ValueError("dias tem que ser entre 0 e 365")
        if dias < 0 or dias > 365:
            raise ValueError("dias tem que ser entre 0 e 365")
        return [l.virar_dict() for l in self.repo.listar_vencendo(dias)]
