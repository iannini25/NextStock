from repositories.lote_repository import LoteRepository


# lotes com saldo que vencem nos proximos X dias (inclui os vencidos)
class ListarLotesVencendoService:

    def executar(self, dias):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 7
        if dias < 0 or dias > 365:
            raise ValueError("dias tem que ser entre 0 e 365")
        return [l.virar_dict() for l in LoteRepository().listar_vencendo(dias)]
