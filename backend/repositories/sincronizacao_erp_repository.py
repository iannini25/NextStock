from sqlalchemy.orm import joinedload
from models.sincronizacao_erp_model import SincronizacaoErp


class SincronizacaoErpRepository:
    def em_andamento(self):
        return SincronizacaoErp.query.filter_by(status="em_andamento").first()

    def ultima_com_sucesso(self):
        return SincronizacaoErp.query.filter_by(status="sucesso").order_by(
            SincronizacaoErp.id_sincronizacao.desc()).first()

    def listar_recentes(self, limite):
        return SincronizacaoErp.query.options(joinedload(SincronizacaoErp.usuario)).order_by(
            SincronizacaoErp.id_sincronizacao.desc()).limit(limite).all()
