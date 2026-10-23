from datetime import datetime
from models.database import db
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from repositories.movimentacao_repository import MovimentacaoRepository


class PreencherHistoricoService:
    def __init__(self, repo=None):
        self.repo = repo if repo is not None else MovimentacaoRepository()

    def executar(self):
        if self.repo.historico_preenchido():
            return 0
        from models.venda_model import Venda

        criados = 0
        tipos_por_origem_do_lote = {"inicial": "saldo_inicial", "ajuste": "ajuste_entrada"}
        for lote in Lote.listar_todos():
            MovimentacaoEstoque(
                id_produto=lote.id_produto,
                id_lote=lote.id_lote,
                tipo=tipos_por_origem_do_lote.get(lote.origem, "entrada"),
                quantidade=lote.quantidade_inicial,
                custo_unitario=lote.custo_unitario,
                id_usuario=lote.id_usuario,
                origem="historico",
                data_hora=lote.criado_em or datetime.combine(lote.data_entrada, datetime.min.time()),
            ).salvar(confirmar=False)
            criados += 1
        for venda in Venda.listar_todos():
            MovimentacaoEstoque(
                id_produto=venda.id_produto,
                tipo="venda",
                quantidade=venda.quantidade,
                id_venda=venda.id_venda,
                origem="historico",
                observacao="venda registrada antes do histórico de movimentações",
                data_hora=datetime.combine(venda.data_venda, datetime.min.time()),
            ).salvar(confirmar=False)
            criados += 1
        if criados:
            db.session.commit()
        return criados
