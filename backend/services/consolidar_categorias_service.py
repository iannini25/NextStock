from models.categoria_model import Categoria
from models.database import db
from repositories.produto_repository import ProdutoRepository


class ConsolidarCategoriasService:
    """Mantém o menor ID e transfere produtos em uma única transação."""

    def __init__(self, categoria_model=None, repo_produto=None):
        self.categoria_model = categoria_model if categoria_model is not None else Categoria
        self.repo_produto = repo_produto if repo_produto is not None else ProdutoRepository()

    def executar(self, aplicar=False):
        grupos = {}
        for categoria in sorted(self.categoria_model.listar_todos(), key=lambda c: c.id_categoria):
            grupos.setdefault(categoria.nome.strip().lower(), []).append(categoria)
        resultado = []
        try:
            for categorias in grupos.values():
                if len(categorias) < 2:
                    continue
                fica, *repetidas = categorias
                ids = [c.id_categoria for c in repetidas]
                produtos = self.repo_produto.listar_por_categorias(ids)
                if aplicar:
                    for produto in produtos:
                        produto.id_categoria = fica.id_categoria
                        produto.salvar(confirmar=False)
                    for categoria in repetidas:
                        categoria.deletar(confirmar=False)
                resultado.append((fica, ids, len(produtos)))
            if aplicar:
                db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return resultado
