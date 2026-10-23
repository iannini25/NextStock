from services.priorizar_lotes_service import PriorizarLotesService
from services.utils import inteiro


class PlanejarSaidaService:
    """Calcula as parcelas por lote e a falta, sem alterar nem persistir estoque."""

    def __init__(self, prioridade=None):
        self.prioridade = prioridade if prioridade is not None else PriorizarLotesService()

    @staticmethod
    def validar_quantidade(quantidade):
        if isinstance(quantidade, (bool, float)):
            raise ValueError("valor precisa ser numero inteiro")
        quantidade = inteiro(quantidade)
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        return quantidade

    def executar(self, lotes, quantidade, hoje=None):
        falta = self.validar_quantidade(quantidade)
        plano = []
        com_saldo = [lote for lote in lotes if lote.quantidade_atual > 0]
        for lote in self.prioridade.executar(com_saldo, hoje=hoje):
            if falta == 0:
                break
            sai = min(falta, lote.quantidade_atual)
            plano.append((lote, sai))
            falta -= sai
        return plano, falta
