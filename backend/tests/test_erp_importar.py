from models.categoria_model import Categoria
from models.produto_model import Produto
from tests.fabricas import criar_produto


def test_sem_dados(client):
    r = client.post("/erp/importar", json={})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "manda pelo menos produtos ou vendas"}


def test_cria_produto_e_categoria_pelo_nome(client):
    r = client.post("/erp/importar", json={"produtos": [{
        "codigo_barras": "111",
        "nome": "Arroz 5kg",
        "preco_venda": 25,
        "categoria": "Mercearia",
        "quantidade_estoque": 10,
    }]})
    assert r.status_code == 200
    assert r.get_json() == {"produtos_criados": 1, "produtos_atualizados": 0, "vendas_importadas": 0, "erros": []}
    arroz = Produto.buscar_por_codigo("111")
    assert arroz.categoria.nome == "Mercearia"
    assert Categoria.query.count() == 1


# comportamento atual (a Etapa 6 do plano mantem isso no /erp/importar):
# o que o ERP nao manda volta pro padrao (estoque_minimo vira 0).
def test_atualiza_produto_existente_e_zera_campos_nao_enviados(client):
    criar_produto("Arroz", codigo_barras="111", estoque_minimo=7)
    r = client.post("/erp/importar", json={"produtos": [
        {"codigo_barras": "111", "nome": "Arroz 5kg", "preco_venda": 25, "quantidade_estoque": 4},
    ]})
    assert r.get_json()["produtos_atualizados"] == 1
    arroz = Produto.buscar_por_codigo("111")
    assert arroz.nome == "Arroz 5kg"
    assert arroz.quantidade_estoque == 4
    assert arroz.estoque_minimo == 0


# comportamento atual: o estoque do produto e gravado e depois cada venda importada baixa de novo
def test_venda_importada_baixa_o_estoque_do_produto_importado(client):
    r = client.post("/erp/importar", json={
        "produtos": [{"codigo_barras": "111", "nome": "Arroz", "preco_venda": 25, "quantidade_estoque": 10}],
        "vendas": [{"codigo_barras": "111", "quantidade": 3, "data_venda": "2026-01-05"}],
    })
    assert r.get_json()["vendas_importadas"] == 1
    assert Produto.buscar_por_codigo("111").quantidade_estoque == 7


def test_erros_ficam_na_lista_e_o_resto_e_importado(client):
    r = client.post("/erp/importar", json={
        "produtos": [
            {"codigo_barras": "222", "preco_venda": 1},
            {"codigo_barras": "333", "nome": "Sem preço"},
            {"codigo_barras": "444", "nome": "Ok", "preco_venda": 2},
        ],
        "vendas": [{"codigo_barras": "999", "quantidade": 1}],
    })
    corpo = r.get_json()
    assert corpo["produtos_criados"] == 1
    assert corpo["erros"] == [
        "produto 222: codigo_barras e nome são obrigatórios",
        "produto 333: preco_venda é obrigatório",
        "venda 999: produto não encontrado",
    ]
