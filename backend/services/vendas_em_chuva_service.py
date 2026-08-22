from datetime import date, timedelta

from repositories.clima_repository import ClimaRepository
from repositories.venda_repository import VendaRepository
from services.atualizar_clima_service import AtualizarClimaService


class VendasEmChuvaService:

    def __init__(self):
        self.repo_clima = ClimaRepository()
        self.repo_venda = VendaRepository()

    def executar(self, dias=30):
        AtualizarClimaService().executar()
        hoje = date.today()
        inicio = hoje - timedelta(days=dias)
        ontem = hoje - timedelta(days=1)

        climas = self.repo_clima.listar_no_periodo(inicio, ontem)
        datas_chuva = {c.data for c in climas if c.condicao in ("chuva", "chuva_forte")}
        datas_forte = {c.data for c in climas if c.condicao == "chuva_forte"}

        vendas = self.repo_venda.listar_por_periodo(inicio, ontem)
        por_chuva = {}
        por_forte = {}
        for v in vendas:
            nome = v.produto.nome if v.produto else str(v.id_produto)
            unidade = v.produto.unidade if v.produto else ""
            if v.data_venda in datas_chuva:
                item = por_chuva.setdefault(nome, {"produto_nome": nome, "unidade": unidade, "quantidade": 0})
                item["quantidade"] += v.quantidade
            if v.data_venda in datas_forte:
                item = por_forte.setdefault(nome, {"produto_nome": nome, "unidade": unidade, "quantidade": 0})
                item["quantidade"] += v.quantidade

        vendas_chuva = sorted(por_chuva.values(), key=lambda x: x["quantidade"], reverse=True)
        vendas_forte = sorted(por_forte.values(), key=lambda x: x["quantidade"], reverse=True)
        return {
            "dias_chuva": sorted(d.isoformat() for d in datas_chuva),
            "dias_chuva_forte": sorted(d.isoformat() for d in datas_forte),
            "vendas_chuva": vendas_chuva,
            "vendas_chuva_forte": vendas_forte,
        }

    def texto(self, dias=30):
        d = self.executar(dias)
        if not d["dias_chuva"]:
            return "Não achei dia de chuva no clima dos últimos " + str(dias) + " dias."

        linhas = [
            "Nos últimos " + str(dias) + " dias teve " + str(len(d["dias_chuva"]))
            + " dia(s) de chuva"
            + ((" (chuva forte em " + str(len(d["dias_chuva_forte"])) + ")") if d["dias_chuva_forte"] else "")
            + ": " + ", ".join(d["dias_chuva"]) + "."
        ]
        if d["vendas_chuva"]:
            linhas.append("Vendas nesses dias de chuva:")
            for item in d["vendas_chuva"]:
                linhas.append("- " + item["produto_nome"] + ": " + str(item["quantidade"]) + " " + str(item["unidade"] or ""))
        else:
            linhas.append("Não teve venda registrada nesses dias de chuva.")

        if d["vendas_chuva_forte"]:
            linhas.append("Nos dias de chuva forte:")
            for item in d["vendas_chuva_forte"]:
                linhas.append("- " + item["produto_nome"] + ": " + str(item["quantidade"]) + " " + str(item["unidade"] or ""))
        return "\n".join(linhas)
