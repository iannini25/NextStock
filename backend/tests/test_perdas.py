from datetime import datetime, timedelta

import pytest

from models.database import db
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.perda_model import Perda
from models.produto_model import Produto
from models.venda_model import Venda
from tests.fabricas import criar_produto, criar_vendas_diarias, dia


def entrada(client, produto, quantidade, **extra):
    return client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra}).get_json()["lote"]


def registrar(client, lote_id, quantidade, motivo="vencimento", tipo="descarte", **extra):
    return client.post("/perdas", json={"id_lote": lote_id, "quantidade": quantidade, "motivo": motivo, "tipo": tipo, **extra})


# ---------- registro ----------

def test_descarte_baixa_o_lote_e_guarda_o_valor(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, preco_custo=2, data_validade=dia(20))
    vencido = entrada(client, queijo, 5, data_validade=dia(-1).isoformat(), custo_unitario=3.5, codigo_lote="V1")

    r = registrar(client, vencido["id_lote"], 4, observacao="mofado")
    assert r.status_code == 201
    corpo = r.get_json()
    perda = corpo["perda"]
    assert (perda["tipo"], perda["motivo"], perda["quantidade"]) == ("descarte", "vencimento", 4)
    assert perda["custo_unitario"] == 3.5  # o custo DESTE lote, nao o do produto
    assert perda["valor_total"] == 14.0
    assert perda["lote"] == "Lote V1"
    assert perda["usuario"] == "Admin"
    assert perda["nome_motivo"] == "Vencimento"
    assert corpo["aviso"] is None

    assert Lote.buscar_por_id(vencido["id_lote"]).quantidade_atual == 1
    assert corpo["produto"]["quantidade_estoque"] == 11  # 10 do lote bom + 1 que sobrou do vencido


def test_perda_sai_do_lote_escolhido_e_nao_pela_fila_de_venda(client):
    leite = criar_produto("Leite", quantidade_estoque=10, data_validade=dia(2))  # esse sairia primeiro numa venda
    avariado = entrada(client, leite, 6, data_validade=dia(30).isoformat())
    registrar(client, avariado["id_lote"], 2, motivo="avaria", tipo="perda")
    saldos = {l.id_lote: l.quantidade_atual for l in Lote.query.all()}
    assert saldos[avariado["id_lote"]] == 4
    assert sorted(saldos.values()) == [4, 10]


def test_perda_gera_movimentacao_ligada(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10)
    lote = Lote.query.one()
    registrar(client, lote.id_lote, 3, motivo="temperatura", tipo="perda", observacao="geladeira desligou")
    mov = MovimentacaoEstoque.query.filter_by(tipo="perda").one()
    assert (mov.quantidade, mov.saldo_produto_apos, mov.id_lote) == (3, 7, lote.id_lote)
    assert mov.observacao == "Temperatura: geladeira desligou"
    assert Perda.query.one().id_movimentacao == mov.id_movimentacao
    ultima = client.get("/movimentacoes").get_json()["itens"][0]
    assert (ultima["tipo"], ultima["sinal"]) == ("perda", -1)


def test_sem_custo_no_lote_usa_o_do_produto(client):
    queijo = criar_produto("Queijo", quantidade_estoque=5, preco_custo=4)
    lote = Lote.query.one()
    lote.custo_unitario = None
    db.session.commit()
    assert registrar(client, lote.id_lote, 2).get_json()["perda"]["valor_total"] == 8.0


def test_sem_custo_nenhum_fica_zero_com_aviso(client):
    criar_produto("Brinde", quantidade_estoque=5, preco_custo=None)
    lote = Lote.query.one()
    corpo = registrar(client, lote.id_lote, 2).get_json()
    assert corpo["perda"]["valor_total"] == 0
    assert "não tem custo cadastrado" in corpo["aviso"]


def test_quantidade_acima_do_saldo_e_recusada(client):
    criar_produto("Queijo", quantidade_estoque=3)
    lote = Lote.query.one()
    r = registrar(client, lote.id_lote, 5)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "o lote só tem 3 em estoque"}
    assert (Lote.query.one().quantidade_atual, Perda.query.count()) == (3, 0)


@pytest.mark.parametrize("mudanca, erro", [
    ({"id_lote": 999}, "lote não existe"),
    ({"quantidade": 0}, "quantidade tem que ser maior que zero"),
    ({"tipo": "roubo"}, "tipo tem que ser perda ou descarte"),
    ({"motivo": "chuva"}, "motivo inválido. use: vencimento, avaria, temperatura, furto, outro"),
    ({"motivo": ""}, "motivo inválido. use: vencimento, avaria, temperatura, furto, outro"),
    ({"observacao": "x" * 256}, "observação pode ter no máximo 255 caracteres"),
])
def test_registro_invalido(client, mudanca, erro):
    criar_produto("Queijo", quantidade_estoque=3)
    dados = {"id_lote": Lote.query.one().id_lote, "quantidade": 1, "motivo": "avaria", "tipo": "perda", **mudanca}
    r = client.post("/perdas", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
    assert Perda.query.count() == 0


def test_usuario_comum_registra_perda(client_usuario):
    criar_produto("Queijo", quantidade_estoque=3)
    r = registrar(client_usuario, Lote.query.one().id_lote, 1)
    assert r.status_code == 201
    assert r.get_json()["perda"]["usuario"] == "Carlos Caixa"


# ---------- perda nao e venda ----------

def test_perda_nao_vira_venda_nem_muda_a_previsao(client):
    leite = criar_produto("Leite", quantidade_estoque=100)
    criar_vendas_diarias(leite, 10)
    antes = {p["produto_nome"]: p["previsao_demanda"] for p in client.get("/previsao").get_json()["previsoes"]}
    vendas_antes = Venda.query.count()

    registrar(client, Lote.query.one().id_lote, 30, motivo="avaria", tipo="perda")

    depois = {p["produto_nome"]: p["previsao_demanda"] for p in client.get("/previsao").get_json()["previsoes"]}
    assert depois == antes
    assert Venda.query.count() == vendas_antes
    assert client.get("/relatorios/consumo").get_json()["total_vendido"] == 280


# ---------- consulta e resumo ----------

def montar_perdas(client):
    queijo = criar_produto("Queijo", quantidade_estoque=20, preco_custo=5)
    leite = criar_produto("Leite", quantidade_estoque=20, preco_custo=2)
    lq = Lote.query.filter_by(id_produto=queijo.id_produto).one()
    ll = Lote.query.filter_by(id_produto=leite.id_produto).one()
    registrar(client, lq.id_lote, 2, motivo="vencimento")  # 10,00
    registrar(client, lq.id_lote, 1, motivo="avaria", tipo="perda")  # 5,00
    registrar(client, ll.id_lote, 4, motivo="vencimento")  # 8,00
    antiga = Perda(produto=leite, lote=ll, tipo="perda", motivo="furto", quantidade=1, custo_unitario=2,
                   valor_total=2, data_registro=datetime.now() - timedelta(days=45))
    db.session.add(antiga)
    db.session.commit()
    return queijo, leite


def test_lista_com_filtros_e_totais(client):
    queijo, leite = montar_perdas(client)
    todas = client.get("/perdas").get_json()
    assert (len(todas["itens"]), todas["valor_total"], todas["quantidade_total"]) == (4, 25.0, 8)
    assert todas["itens"][0]["motivo"] == "vencimento"  # mais recente primeiro (a de 45 dias e a ultima)
    assert todas["itens"][-1]["motivo"] == "furto"

    assert client.get("/perdas?motivo=vencimento").get_json()["valor_total"] == 18.0
    assert client.get("/perdas?tipo=perda").get_json()["quantidade_total"] == 2
    assert len(client.get(f"/perdas?id_produto={queijo.id_produto}").get_json()["itens"]) == 2
    hoje = datetime.now().date().isoformat()
    assert client.get(f"/perdas?inicio={hoje}&fim={hoje}").get_json()["valor_total"] == 23.0


@pytest.mark.parametrize("query, erro", [
    ("?motivo=chuva", "motivo inválido"),
    ("?tipo=x", "tipo tem que ser perda ou descarte"),
    ("?inicio=2026-10-10&fim=2026-10-01", "a data de início tem que ser antes da data de fim"),
    ("?id_produto=abc", "id_produto tem que ser número"),
])
def test_lista_filtro_invalido(client, query, erro):
    r = client.get("/perdas" + query)
    assert r.status_code == 400
    assert r.get_json()["erro"].startswith(erro)


def test_resumo_por_motivo_e_por_produto(client):
    montar_perdas(client)
    resumo = client.get("/perdas/resumo").get_json()  # padrao: 30 dias (a de 45 dias fica de fora)
    assert (resumo["dias"], resumo["valor_total"], resumo["quantidade_total"], resumo["registros"]) == (30, 23.0, 7, 3)
    assert [(m["motivo"], m["valor"], m["quantidade"], m["registros"]) for m in resumo["por_motivo"]] == [
        ("vencimento", 18.0, 6, 2),
        ("avaria", 5.0, 1, 1),
    ]
    assert [(p["produto_nome"], p["valor"]) for p in resumo["por_produto"]] == [("Queijo", 15.0), ("Leite", 8.0)]
    assert client.get("/perdas/resumo?dias=60").get_json()["valor_total"] == 25.0
    assert client.get("/perdas/resumo?dias=0").status_code == 400


# ---------- painel ----------

def test_painel_mostra_as_perdas_e_mantem_os_indicadores_antigos(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, preco_custo=2, data_validade=dia(10))
    vencido = entrada(client, queijo, 5, data_validade=dia(-1).isoformat(), custo_unitario=3)
    antes = client.get("/painel").get_json()
    assert (antes["valor_perdas_30_dias"], antes["quantidade_perdas_30_dias"]) == (0, 0)
    assert antes["valor_vencido"] == 15.0

    registrar(client, vencido["id_lote"], 5)  # descartou os 5 vencidos
    depois = client.get("/painel").get_json()
    assert depois["valor_perdas_30_dias"] == 15.0
    assert depois["quantidade_perdas_30_dias"] == 5
    assert depois["valor_vencido"] == 0  # nao tem mais vencido na prateleira...
    assert depois["valor_perdas_30_dias"] == antes["valor_vencido"]  # ...mas o prejuizo ficou registrado


def test_produto_com_perda_nao_pode_ser_excluido(client):
    queijo = criar_produto("Queijo", quantidade_estoque=3)
    registrar(client, Lote.query.one().id_lote, 1)
    r = client.delete(f"/produtos/{queijo.id_produto}")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "não dá para apagar: esse produto tem perdas registradas"}
    assert Produto.buscar_por_id(queijo.id_produto) is not None
