from models.database import db
from repositories.produto_repository import ProdutoRepository
from services.estoque_lote_service import EstoqueLoteService


class CriarLotesIniciaisService:
    def __init__(self, repo=None, estoque=None):
        self.repo = repo if repo is not None else ProdutoRepository()
        self.estoque = estoque if estoque is not None else EstoqueLoteService(origem_movimento="sistema")

    def executar(self):
        produtos = self.repo.listar_sem_lote_com_estoque()
        try:
            for produto in produtos:
                self.estoque.garantir_lote_inicial(produto)
            if produtos:
                db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return len(produtos)
