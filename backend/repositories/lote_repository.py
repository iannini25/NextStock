from datetime import date, timedelta
from sqlalchemy.orm import joinedload

from models.lote_model import Lote


class LoteRepository:

    # lotes com saldo que vencem ate daqui a X dias (inclui os ja vencidos), o que vence antes primeiro
    def listar_vencendo(self, dias):
        limite = date.today() + timedelta(days=dias)
        return (
            Lote.query.options(joinedload(Lote.produto), joinedload(Lote.usuario))
            .filter(Lote.quantidade_atual > 0)
            .filter(Lote.data_validade.isnot(None))
            .filter(Lote.data_validade <= limite)
            .order_by(Lote.data_validade.asc(), Lote.id_lote.asc())
            .all()
        )

    # lotes vencidos que ainda tem mercadoria (o que esta perdido de verdade)
    def listar_vencidos_com_saldo(self):
        return (
            Lote.query
            .filter(Lote.quantidade_atual > 0)
            .filter(Lote.data_validade.isnot(None))
            .filter(Lote.data_validade < date.today())
            .all()
        )
