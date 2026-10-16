from datetime import datetime

from .database import db


# vendas que ja vieram do ERP (pelo id que o ERP da pra elas): sincronizar de novo nao duplica
class ErpVendaImportada(db.Model):
    __tablename__ = "erp_venda_importada"

    id_externo = db.Column(db.String(100), primary_key=True)
    id_venda = db.Column(db.Integer, db.ForeignKey("venda.id_venda"), nullable=False)
    importado_em = db.Column(db.DateTime, nullable=False, default=datetime.now)

    @staticmethod
    def ja_importada(id_externo):
        return db.session.get(ErpVendaImportada, id_externo) is not None
