from datetime import date
from io import BytesIO

import pytest

from models.database import db
from models.lote_model import Lote
from models.produto_model import Produto
from services.estoque_lote_service import criar_lotes_iniciais, ordenar_lotes_para_saida
from tests.fabricas import criar_produto, dia


def conferir_invariante():
    # regra central: o estoque de todo produto e exatamente a soma dos saldos dos lotes
    for p in Produto.query.all():
        soma = sum(l.quantidade_atual for l in Lote.query.filter_by(id_produto=p.id_produto))
        assert p.quantidade_estoque == soma, f"{p.nome}: estoque {p.quantidade_estoque} != lotes {soma}"


def lotes(client, produto, todos=False):
    r = client.get(f"/produtos/{produto.id_produto}/lotes" + ("?todos=1" if todos else ""))
    assert r.status_code == 200
    return r.get_json()["lotes"]


def entrada(client, produto, quantidade, **extra):
    return client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra})


def produto_atual(client, produto):
    return client.get(f"/produtos/{produto.id_produto}").get_json()


# ---------- migracao ----------

def test_migracao_cria_o_estoque_inicial_uma_vez_so(banco):
    antigo = Produto(nome="Antigo", preco_venda=5, quantidade_estoque=12, preco_custo=3, data_validade=dia(9))
    sem_estoque = Produto(nome="Sem estoque", preco_venda=5, quantidade_estoque=0)
    db.session.add_all([antigo, sem_estoque])
    db.session.commit()  # como estava no banco antes dos lotes

    assert criar_lotes_iniciais() == 1
    assert criar_lotes_iniciais() == 0  # rodar de novo nao duplica
    lote = Lote.query.one()
    assert (lote.id_produto, lote.quantidade_atual, lote.data_validade, lote.origem) == (antigo.id_produto, 12, dia(9), "inicial")
    assert float(lote.custo_unitario) == 3
    conferir_invariante()


# ---------- entrada de mercadoria ----------

def test_entrada_cria_lote_e_soma_no_estoque(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10), preco_custo=3)
    r = entrada(client, leite, 20, data_validade=dia(4).isoformat(), codigo_lote="L-778", custo_unitario="3.40")
    assert r.status_code == 201
    corpo = r.get_json()
    assert corpo["lote"]["quantidade_atual"] == 20
    assert corpo["lote"]["codigo_lote"] == "L-778"
    assert corpo["lote"]["custo_unitario"] == 3.4
    assert corpo["lote"]["origem"] == "entrada"
    assert corpo["lote"]["usuario"] == "Admin"
    assert corpo["lote"]["dias_para_vencer"] == 4
    assert corpo["produto"]["quantidade_estoque"] == 25
    assert corpo["produto"]["data_validade"] == dia(4).isoformat()  # a menor validade entre os lotes
    conferir_invariante()


def test_entrada_sem_custo_usa_o_custo_do_produto(client):
    leite = criar_produto("Leite", preco_custo=3.2)
    assert entrada(client, leite, 5).get_json()["lote"]["custo_unitario"] == 3.2


@pytest.mark.parametrize("dados, erro", [
    ({"quantidade": 0}, "quantidade tem que ser maior que zero"),
    ({"quantidade": -3}, "valor nao pode ser negativo"),
    ({"quantidade": 5, "data_validade": "10/12/2026"}, "data tem que ser aaaa-mm-dd"),
    ({"quantidade": 5, "data_entrada": "2099-01-01"}, "data de entrada não pode ser no futuro"),
    ({"quantidade": 5, "custo_unitario": "-1"}, "valor nao pode ser negativo"),
    ({"quantidade": 5, "codigo_lote": "x" * 51}, "código do lote pode ter no máximo 50 caracteres"),
])
def test_entrada_invalida(client, dados, erro):
    leite = criar_produto("Leite")
    r = client.post("/lotes", json={"id_produto": leite.id_produto, **dados})
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
    assert Lote.query.count() == 0


def test_entrada_de_produto_inexistente(client):
    r = client.post("/lotes", json={"id_produto": 999, "quantidade": 1})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "produto não existe"}


def test_usuario_comum_registra_entrada(client_usuario):
    leite = criar_produto("Leite")
    assert entrada(client_usuario, leite, 3).status_code == 201


# ---------- ordem de saida e baixa ----------

def test_ordem_de_saida():
    a = Lote(id_lote=1, data_validade=dia(10), data_entrada=dia(-5))
    b = Lote(id_lote=2, data_validade=dia(3), data_entrada=dia(-1))
    c = Lote(id_lote=3, data_validade=None, data_entrada=dia(-9))
    d = Lote(id_lote=4, data_validade=dia(3), data_entrada=dia(-4))  # mesma validade de b, entrou antes
    assert [l.id_lote for l in ordenar_lotes_para_saida([a, b, c, d])] == [4, 2, 1, 3]


def test_venda_tira_primeiro_do_lote_que_vence_antes_e_atravessa_lotes(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10))
    entrada(client, leite, 10, data_validade=dia(3).isoformat())
    r = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 12})
    assert r.status_code == 201

    saldos = {l["data_validade"]: l["quantidade_atual"] for l in lotes(client, leite, todos=True)}
    assert saldos == {dia(3).isoformat(): 0, dia(10).isoformat(): 3}
    p = produto_atual(client, leite)
    assert p["quantidade_estoque"] == 3
    assert p["data_validade"] == dia(10).isoformat()  # o lote que acabou nao conta mais
    conferir_invariante()


def test_lote_sem_validade_sai_por_ultimo(client):
    arroz = criar_produto("Arroz", quantidade_estoque=4)  # lote inicial sem validade
    entrada(client, arroz, 4, data_validade=dia(60).isoformat())
    client.post("/vendas", json={"id_produto": arroz.id_produto, "quantidade": 3})
    saldos = {l["data_validade"]: l["quantidade_atual"] for l in lotes(client, arroz)}
    assert saldos == {dia(60).isoformat(): 1, None: 4}


def test_venda_sem_estoque_suficiente_nao_mexe_em_nada(client):
    leite = criar_produto("Leite", quantidade_estoque=5)
    entrada(client, leite, 3)
    r = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 9})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "estoque insuficiente"}
    assert sorted(l["quantidade_atual"] for l in lotes(client, leite)) == [3, 5]
    conferir_invariante()


def test_falha_ao_gravar_a_venda_nao_deixa_estado_pela_metade(client, monkeypatch):
    leite = criar_produto("Leite", quantidade_estoque=10)

    def commit_quebrado():
        raise RuntimeError("banco caiu")

    monkeypatch.setattr(db.session, "commit", commit_quebrado)
    with pytest.raises(RuntimeError):
        from services.registrar_venda_service import RegistrarVendaService
        RegistrarVendaService().executar({"id_produto": leite.id_produto, "quantidade": 4})
    monkeypatch.undo()

    assert Lote.query.one().quantidade_atual == 10
    assert Produto.buscar_por_id(leite.id_produto).quantidade_estoque == 10
    conferir_invariante()


# ---------- cadastro e edicao de produto ----------

def test_cadastro_com_quantidade_cria_o_lote_inicial(client):
    r = client.post("/produtos", json={"nome": "Iogurte", "preco_venda": 3.5, "preco_custo": 1.8,
                                       "quantidade_estoque": 30, "data_validade": dia(15).isoformat()})
    p = r.get_json()
    assert p["quantidade_estoque"] == 30
    assert p["data_validade"] == dia(15).isoformat()
    lote = Lote.query.one()
    assert (lote.quantidade_atual, lote.data_validade, lote.origem) == (30, dia(15), "inicial")
    assert float(lote.custo_unitario) == 1.8


def test_cadastro_sem_quantidade_nao_cria_lote(client):
    p = client.post("/produtos", json={"nome": "Iogurte", "preco_venda": 3.5, "data_validade": dia(15).isoformat()}).get_json()
    assert p["quantidade_estoque"] == 0
    assert p["data_validade"] is None  # validade e do lote; sem lote nao tem validade
    assert Lote.query.count() == 0


def test_edicao_sem_quantidade_mantem_o_estoque(client):
    leite = criar_produto("Leite", quantidade_estoque=10, data_validade=dia(5))
    for corpo in ({"nome": "Leite Integral", "preco_venda": 6},
                  {"nome": "Leite Integral", "preco_venda": 6, "quantidade_estoque": None, "data_validade": None}):
        r = client.put(f"/produtos/{leite.id_produto}", json=corpo)
        assert r.status_code == 200
        assert r.get_json()["nome"] == "Leite Integral"
        assert r.get_json()["quantidade_estoque"] == 10
        assert r.get_json()["data_validade"] == dia(5).isoformat()
    assert Lote.query.count() == 1


def test_edicao_com_quantidade_maior_cria_lote_de_ajuste(client):
    leite = criar_produto("Leite", quantidade_estoque=10, data_validade=dia(5))
    r = client.put(f"/produtos/{leite.id_produto}", json={"nome": "Leite", "preco_venda": 5,
                                                         "quantidade_estoque": 14, "data_validade": dia(20).isoformat()})
    assert r.get_json()["quantidade_estoque"] == 14
    ajuste = Lote.query.filter_by(origem="ajuste").one()
    assert (ajuste.quantidade_atual, ajuste.data_validade) == (4, dia(20))
    conferir_invariante()


def test_edicao_com_quantidade_menor_baixa_pela_ordem_de_saida(client):
    leite = criar_produto("Leite", quantidade_estoque=10, data_validade=dia(30))
    entrada(client, leite, 5, data_validade=dia(2).isoformat())
    r = client.put(f"/produtos/{leite.id_produto}", json={"nome": "Leite", "preco_venda": 5, "quantidade_estoque": 8})
    assert r.get_json()["quantidade_estoque"] == 8
    saldos = {l["data_validade"]: l["quantidade_atual"] for l in lotes(client, leite, todos=True)}
    assert saldos == {dia(2).isoformat(): 0, dia(30).isoformat(): 8}
    conferir_invariante()


def test_excluir_produto_apaga_os_lotes(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    entrada(client, leite, 5)
    assert client.delete(f"/produtos/{leite.id_produto}").status_code == 204
    assert Lote.query.count() == 0


# ---------- importacoes ----------

def test_importar_planilha_ajusta_pelos_lotes(client):
    leite = criar_produto("Leite", codigo_barras="789", quantidade_estoque=10)
    csv = "nome,codigo_barras,preco_venda,quantidade_estoque,data_validade\nLeite,789,5,25,2030-01-01\nNovo,790,2,7,\n"
    r = client.post("/importar?modulo=produtos", data={"arquivo": (BytesIO(csv.encode()), "p.csv")},
                    content_type="multipart/form-data")
    assert r.get_json()["importados"] == 2
    assert produto_atual(client, leite)["quantidade_estoque"] == 25
    assert Lote.query.filter_by(origem="importacao").count() == 2  # o ajuste do leite + o lote do produto novo
    conferir_invariante()


def test_planilha_sem_coluna_de_quantidade_mantem_o_estoque(client):
    leite = criar_produto("Leite", codigo_barras="789", quantidade_estoque=10)
    csv = "nome,codigo_barras,preco_venda\nLeite Integral,789,6.5\n"
    client.post("/importar?modulo=produtos", data={"arquivo": (BytesIO(csv.encode()), "p.csv")},
                content_type="multipart/form-data")
    p = produto_atual(client, leite)
    assert (p["nome"], p["quantidade_estoque"]) == ("Leite Integral", 10)


def test_importar_pelo_erp_mantem_os_lotes_coerentes(client):
    r = client.post("/erp/importar", json={
        "produtos": [{"codigo_barras": "111", "nome": "Arroz", "preco_venda": 25, "quantidade_estoque": 10}],
        "vendas": [{"codigo_barras": "111", "quantidade": 3}],
    })
    assert r.get_json()["vendas_importadas"] == 1
    assert Produto.buscar_por_codigo("111").quantidade_estoque == 7
    conferir_invariante()


# ---------- painel e vencimento ----------

def test_painel_soma_so_os_lotes_vencidos(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, preco_custo=2, data_validade=dia(10))
    entrada(client, queijo, 5, data_validade=dia(-1).isoformat(), custo_unitario=3)
    painel = client.get("/painel").get_json()
    assert painel["valor_vencido"] == 15.0  # so os 5 vencidos (a R$ 3), nao o estoque inteiro
    assert painel["produtos_vencidos"] == 1


def test_lotes_vencendo(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, data_validade=dia(20))
    entrada(client, queijo, 4, data_validade=dia(-2).isoformat())
    entrada(client, queijo, 6, data_validade=dia(3).isoformat())
    acabou = criar_produto("Acabou")
    entrada(client, acabou, 1, data_validade=dia(1).isoformat())
    client.post("/vendas", json={"id_produto": acabou.id_produto, "quantidade": 1})  # sem saldo: nao aparece

    r = client.get("/lotes/vencendo?dias=7")
    assert r.status_code == 200
    assert [(l["produto_nome"], l["quantidade_atual"], l["vencido"]) for l in r.get_json()] == [
        ("Queijo", 4, True),
        ("Queijo", 6, False),
    ]
    assert len(client.get("/lotes/vencendo?dias=30").get_json()) == 3
    assert client.get("/lotes/vencendo?dias=400").status_code == 400


# ---------- consultar e corrigir lotes ----------

def test_lista_os_lotes_na_ordem_de_saida_e_os_esgotados_com_todos(client):
    leite = criar_produto("Leite", quantidade_estoque=2, data_validade=dia(9))
    entrada(client, leite, 3, data_validade=dia(4).isoformat())
    client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 3})  # esgota o de 4 dias

    corpo = client.get(f"/produtos/{leite.id_produto}/lotes").get_json()
    assert corpo["produto"]["nome"] == "Leite"
    assert [l["data_validade"] for l in corpo["lotes"]] == [dia(9).isoformat()]
    assert len(lotes(client, leite, todos=True)) == 2
    assert client.get("/produtos/999/lotes").status_code == 404


def test_corrigir_validade_atualiza_a_validade_do_produto(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10))
    lote = Lote.query.one()
    r = client.put(f"/lotes/{lote.id_lote}", json={"codigo_lote": "ABC", "data_validade": dia(2).isoformat()})
    assert r.status_code == 200
    assert r.get_json()["lote"]["codigo_lote"] == "ABC"
    assert r.get_json()["lote"]["quantidade_atual"] == 5  # quantidade nao muda por aqui
    assert produto_atual(client, leite)["data_validade"] == dia(2).isoformat()


def test_corrigir_lote_invalido_ou_inexistente(client):
    criar_produto("Leite", quantidade_estoque=5)
    lote = Lote.query.one()
    assert client.put(f"/lotes/{lote.id_lote}", json={"data_validade": "amanha"}).status_code == 400
    assert client.put("/lotes/999", json={}).status_code == 404


def test_produto_antigo_sem_lote_ganha_o_estoque_inicial_ao_listar(client):
    p = Produto(nome="Antigo", preco_venda=5, quantidade_estoque=8, data_validade=dia(5))
    db.session.add(p)
    db.session.commit()
    assert [(l["quantidade_atual"], l["origem"]) for l in lotes(client, p)] == [(8, "inicial")]


def test_vendas_de_produto_antigo_sem_lote_continuam_funcionando(client):
    p = Produto(nome="Antigo", preco_venda=5, quantidade_estoque=8)
    db.session.add(p)
    db.session.commit()
    assert client.post("/vendas", json={"id_produto": p.id_produto, "quantidade": 3}).status_code == 201
    assert Produto.buscar_por_id(p.id_produto).quantidade_estoque == 5
    conferir_invariante()


def test_data_de_entrada_padrao_e_hoje(client):
    leite = criar_produto("Leite")
    assert entrada(client, leite, 1).get_json()["lote"]["data_entrada"] == date.today().isoformat()
