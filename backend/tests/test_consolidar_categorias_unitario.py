import pytest

from models.categoria_model import Categoria
from models.produto_model import Produto
from services.consolidar_categorias_service import ConsolidarCategoriasService
from tests.fabricas import criar_categoria, criar_produto


def test_falha_na_exclusao_reverte_produtos_e_categorias(monkeypatch):
    criar_categoria("Leite")
    repetida = criar_categoria(" leite ")
    produto = criar_produto("Integral", id_categoria=repetida.id_categoria)
    id_produto, id_repetida = produto.id_produto, repetida.id_categoria

    def falhar(*args, **kwargs):
        raise RuntimeError("falha de persistência")

    monkeypatch.setattr(Categoria, "deletar", falhar)
    with pytest.raises(RuntimeError):
        ConsolidarCategoriasService().executar(aplicar=True)
    assert Categoria.query.count() == 2
    assert Produto.buscar_por_id(id_produto).id_categoria == id_repetida
