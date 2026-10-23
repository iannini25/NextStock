from models.categoria_model import Categoria
from models.produto_model import Produto
from scripts.juntar_categorias_repetidas import juntar_categorias_repetidas
from tests.fabricas import criar_categoria, criar_produto


def montar_repetidas():
    # igual ao banco depois do create_database.sql rodar duas vezes
    hort1 = criar_categoria("Hortifruti")
    lat1 = criar_categoria("Laticínios")
    hort2 = criar_categoria("Hortifruti")
    lat2 = criar_categoria("laticínios ")
    criar_categoria("Padaria")
    criar_produto("Banana", id_categoria=hort1.id_categoria)
    criar_produto("Alface", id_categoria=hort2.id_categoria)  # produto apontando pra repetida
    return hort1, lat1, hort2, lat2


def test_sem_aplicar_nao_muda_nada(banco):
    montar_repetidas()
    resultado = juntar_categorias_repetidas(aplicar=False)
    assert len(resultado) == 2
    assert Categoria.query.count() == 5


def test_junta_mantendo_a_mais_antiga_e_move_os_produtos(banco):
    hort1, lat1, hort2, lat2 = montar_repetidas()
    resultado = juntar_categorias_repetidas(aplicar=True)

    assert [(fica.id_categoria, ids, movidos) for fica, ids, movidos in resultado] == [
        (hort1.id_categoria, [hort2.id_categoria], 1),
        (lat1.id_categoria, [lat2.id_categoria], 0),
    ]
    assert sorted(c.nome for c in Categoria.query.all()) == ["Hortifruti", "Laticínios", "Padaria"]
    alface = Produto.query.filter_by(nome="Alface").one()
    assert alface.id_categoria == hort1.id_categoria


def test_sem_repetidas_nao_faz_nada(banco):
    criar_categoria("Padaria")
    assert juntar_categorias_repetidas(aplicar=True) == []
    assert Categoria.query.count() == 1
