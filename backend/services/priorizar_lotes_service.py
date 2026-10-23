from datetime import date


class PriorizarLotesService:
    """PVPS, sem validade após os válidos e vencidos no fim; desempate PEPS/ID."""

    def __init__(self, hoje=None):
        self.hoje = hoje if hoje is not None else date.today

    def executar(self, lotes, hoje=None):
        hoje = hoje if hoje is not None else self.hoje()
        return sorted(lotes, key=lambda lote: (
            lote.data_validade is not None and lote.data_validade < hoje,
            lote.data_validade is None,
            lote.data_validade or date.max,
            lote.data_entrada or date.min,
            lote.id_lote or 0,
        ))
