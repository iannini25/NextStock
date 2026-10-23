from services.formato_planilha import _texto, _numero, _data
from services.utils import inteiro
from models.categoria_model import Categoria
from repositories.categoria_repository import CategoriaRepository


class ImportarCategoriaPlanilhaService:

    def __init__(self, repo=None):
        self.repo = repo if repo is not None else CategoriaRepository()

    def executar(self, item):
        nome = _texto(item.get("nome"))
        if not nome:
            raise ValueError("nome é obrigatório")
        if self.repo.existe_nome_exato(nome):
            return "skip"
        descricao = _texto(item.get("descricao")) or None
        Categoria(nome=nome, descricao=descricao).salvar()
        return "ok"
