import math
from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository
from repositories.evento_repository import EventoRepository


class PreverDemandaService:

    FATORES_CLIMA = {"normal": 1.0, "calor": 1.2, "frio": 0.9, "chuva": 0.8}

    def __init__(self):
        self.repo_venda = VendaRepository()
        self.repo_evento = EventoRepository()

    def executar(self, dias, clima):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 7
        if dias < 1 or dias > 365:
            raise ValueError("dias tem que ser entre 1 e 365")
        if clima not in self.FATORES_CLIMA:
            raise ValueError("clima tem que ser normal, calor, frio ou chuva")

        lista = []
        for produto in Produto.listar_todos():
            lista.append(self.prever_produto(produto, dias, clima))
        lista.sort(key=lambda p: p["previsao_demanda"], reverse=True)
        return lista

    def prever_produto(self, produto, dias, clima):
        hoje = date.today()
        inicio = hoje - timedelta(days=30)
        ontem = hoje - timedelta(days=1)
        vendas = self.repo_venda.listar_por_produto(produto.id_produto, inicio, ontem)

        total = 0
        por_dia_semana = [0, 0, 0, 0, 0, 0, 0]
        for venda in vendas:
            total += venda.quantidade
            por_dia_semana[venda.data_venda.weekday()] += venda.quantidade
        media_diaria = total / 30

        eventos = self.repo_evento.listar_no_periodo(hoje, hoje + timedelta(days=dias))

        previsao = 0
        dias_com_evento = 0
        for i in range(1, dias + 1):
            dia = hoje + timedelta(days=i)
            base = por_dia_semana[dia.weekday()] / 4
            if base == 0:
                base = media_diaria
            fator_evento = 1
            for evento in eventos:
                if evento.data_inicio <= dia <= evento.data_fim:
                    fator_evento += (evento.impacto_percentual or 0) / 100
            if fator_evento != 1:
                dias_com_evento += 1
            previsao += base * self.FATORES_CLIMA[clima] * fator_evento

        return {
            "id_produto": produto.id_produto,
            "produto_nome": produto.nome,
            "unidade": produto.unidade,
            "estoque_atual": produto.quantidade_estoque or 0,
            "media_diaria": round(media_diaria, 2),
            "fator_clima": self.FATORES_CLIMA[clima],
            "dias_com_evento": dias_com_evento,
            "previsao_demanda": math.ceil(previsao),
        }
