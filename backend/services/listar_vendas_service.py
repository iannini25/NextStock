from datetime import date, timedelta

from repositories.venda_repository import VendaRepository


class ListarVendasService:

    def __init__(self):
        self.repo = VendaRepository()

    def executar(self, dias):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 30
        if dias < 1 or dias > 365:
            raise ValueError("dias tem que ser entre 1 e 365")

        hoje = date.today()
        inicio = hoje - timedelta(days=dias)
        return [v.virar_dict() for v in self.repo.listar_por_periodo(inicio, hoje)]
