from sqlalchemy import func

from models.database import db
from models.venda_model import Venda


class VendaRepository:

    def listar_por_periodo(self, inicio, fim):
        return (
            Venda.query
            .filter(Venda.data_venda >= inicio)
            .filter(Venda.data_venda <= fim)
            .order_by(Venda.data_venda.desc())
            .all()
        )

    def listar_por_produto(self, id_produto, inicio, fim):
        return (
            Venda.query
            .filter(Venda.id_produto == id_produto)
            .filter(Venda.data_venda >= inicio)
            .filter(Venda.data_venda <= fim)
            .order_by(Venda.data_venda.desc())
            .all()
        )

    def total_vendido(self, id_produto, inicio, fim):
        total = (
            db.session.query(func.sum(Venda.quantidade))
            .filter(Venda.id_produto == id_produto)
            .filter(Venda.data_venda >= inicio)
            .filter(Venda.data_venda <= fim)
            .scalar()
        )
        return int(total or 0)
