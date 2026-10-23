from datetime import datetime, time

from sqlalchemy.orm import joinedload

from models.movimentacao_estoque_model import MovimentacaoEstoque


class MovimentacaoRepository:
    def historico_preenchido(self):
        return MovimentacaoEstoque.query.first() is not None

    def listar_com_filtros(self, id_produto=None, id_lote=None, tipo=None, origem=None,
                          inicio=None, fim=None, pagina=1, limite=50):
        consulta = MovimentacaoEstoque.query
        for campo, valor in (("id_produto", id_produto), ("id_lote", id_lote), ("tipo", tipo), ("origem", origem)):
            if valor:
                consulta = consulta.filter(getattr(MovimentacaoEstoque, campo) == valor)
        if inicio:
            consulta = consulta.filter(MovimentacaoEstoque.data_hora >= datetime.combine(inicio, time.min))
        if fim:
            consulta = consulta.filter(MovimentacaoEstoque.data_hora <= datetime.combine(fim, time.max))
        total = consulta.count()
        itens = consulta.options(joinedload(MovimentacaoEstoque.produto),
                                  joinedload(MovimentacaoEstoque.lote),
                                  joinedload(MovimentacaoEstoque.usuario)).order_by(
            MovimentacaoEstoque.data_hora.desc(), MovimentacaoEstoque.id_movimentacao.desc()
        ).offset((pagina - 1) * limite).limit(limite).all()
        return itens, total
