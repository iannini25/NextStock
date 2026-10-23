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


def test_quantidade_acima_do_saldo_e_recusada(client):
    criar_produto("Queijo", quantidade_estoque=3)
    lote = Lote.query.one()
    r = registrar(client, lote.id_lote, 5)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "o lote só tem 3 em estoque"}
    assert (Lote.query.one().quantidade_atual, Perda.query.count()) == (3, 0)


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
