from models.categoria_model import Categoria


class CategoriaRepository:
    def existe_nome_exato(self, nome):
        return Categoria.query.filter_by(nome=nome).first() is not None
