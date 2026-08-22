from datetime import date, timedelta

from repositories.clima_repository import ClimaRepository
from services.atualizar_clima_service import AtualizarClimaService


class ListarClimaService:

    def __init__(self):
        self.repo = ClimaRepository()

    def executar(self, inicio=None, fim=None):
        AtualizarClimaService().executar()
        hoje = date.today()
        if inicio is None:
            inicio = hoje - timedelta(days=30)
        if fim is None:
            fim = hoje + timedelta(days=16)
        rows = self.repo.listar_no_periodo(inicio, fim)
        return {
            "cidade": AtualizarClimaService().cidade(),
            "fonte": "open-meteo" if rows else "nenhum",
            "dias": [r.virar_dict() for r in rows],
        }

    def texto_proximos(self, dias=7):
        hoje = date.today()
        dados = self.executar(hoje, hoje + timedelta(days=dias))
        if not dados["dias"]:
            return "Não achei clima para os próximos dias (falhou baixar o Open-Meteo)."
        partes = []
        for d in dados["dias"]:
            partes.append(
                d["data"] + " " + d["condicao"]
                + " " + str(d["chuva_mm"] if d["chuva_mm"] is not None else 0) + "mm"
                + " " + str(d["temperatura"] if d["temperatura"] is not None else "-") + "°C"
            )
        return "Clima em " + dados["cidade"] + ": " + "; ".join(partes)
