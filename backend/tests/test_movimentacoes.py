from datetime import date, datetime, timedelta
from io import BytesIO

import pytest

from models.database import db
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.produto_model import Produto
from models.venda_model import Venda
from services.estoque_lote_service import criar_lotes_iniciais, preencher_historico
from tests.fabricas import criar_produto, dia


def historico(client, **filtros):
    r = client.get("/movimentacoes", query_string=filtros)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def resumo(itens):
    # (tipo, quantidade, saldo depois) do mais antigo pro mais novo
    return [(m["tipo"], m["quantidade"], m["saldo_produto_apos"]) for m in reversed(itens)]


def entrada(client, produto, quantidade, **extra):
    return client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra})


# ---------- cada operacao gera os registros certos ----------

def test_entrada_de_mercadoria(client):
    leite = criar_produto("Leite", quantidade_estoque=5)
    entrada(client, leite, 20, codigo_lote="L-1", custo_unitario=3.5)
    ultima = historico(client)["itens"][0]
    assert ultima["tipo"] == "entrada"
    assert ultima["nome_tipo"] == "Entrada"
    assert ultima["sinal"] == 1
    assert ultima["quantidade"] == 20
    assert ultima["saldo_produto_apos"] == 25
    assert ultima["lote"] == "Lote L-1"
    assert ultima["custo_unitario"] == 3.5
    assert ultima["usuario"] == "Admin"
    assert ultima["origem"] == "manual"
    assert ultima["produto_nome"] == "Leite"


def test_venda_que_atravessa_dois_lotes_gera_dois_registros_da_mesma_venda(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10))
    entrada(client, leite, 10, data_validade=dia(3).isoformat())
    venda = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 12}).get_json()

    vendas = [m for m in historico(client)["itens"] if m["tipo"] == "venda"]
    assert len(vendas) == 2
    assert {m["id_venda"] for m in vendas} == {venda["id_venda"]}
    assert all(m["sinal"] == -1 for m in vendas)
    assert resumo(historico(client, id_produto=leite.id_produto)["itens"]) == [
        ("saldo_inicial", 5, 5),
        ("entrada", 10, 15),
        ("venda", 10, 5),  # primeiro o lote que vence antes
        ("venda", 2, 3),
    ]


def test_venda_recusada_nao_deixa_registro(client):
    leite = criar_produto("Leite", quantidade_estoque=2)
    antes = MovimentacaoEstoque.query.count()
    assert client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 9}).status_code == 400
    assert MovimentacaoEstoque.query.count() == antes
    assert Venda.query.count() == 0


def test_falha_ao_gravar_nao_deixa_registro_orfao(client, monkeypatch):
    leite = criar_produto("Leite", quantidade_estoque=10)
    antes = MovimentacaoEstoque.query.count()

    def commit_quebrado():
        raise RuntimeError("banco caiu")

    monkeypatch.setattr(db.session, "commit", commit_quebrado)
    from services.registrar_venda_service import RegistrarVendaService
    with pytest.raises(RuntimeError):
        RegistrarVendaService().executar({"id_produto": leite.id_produto, "quantidade": 4})
    monkeypatch.undo()
    assert MovimentacaoEstoque.query.count() == antes
    assert Venda.query.count() == 0


def test_cadastro_de_produto_com_quantidade(client):
    p = client.post("/produtos", json={"nome": "Iogurte", "preco_venda": 3, "quantidade_estoque": 30}).get_json()
    assert resumo(historico(client, id_produto=p["id_produto"])["itens"]) == [("saldo_inicial", 30, 30)]


def test_edicao_de_quantidade_vira_ajuste(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    client.put(f"/produtos/{leite.id_produto}", json={"nome": "Leite", "preco_venda": 5, "quantidade_estoque": 14})
    client.put(f"/produtos/{leite.id_produto}", json={"nome": "Leite", "preco_venda": 5, "quantidade_estoque": 9})
    client.put(f"/produtos/{leite.id_produto}", json={"nome": "Leite", "preco_venda": 5})  # sem quantidade: nada
    assert resumo(historico(client, id_produto=leite.id_produto)["itens"]) == [
        ("saldo_inicial", 10, 10),
        ("ajuste_entrada", 4, 14),
        ("ajuste_saida", 5, 9),
    ]


def test_usuario_do_registro_vem_do_token(client_usuario):
    leite = criar_produto("Leite", quantidade_estoque=10)
    client_usuario.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 1})
    assert historico(client_usuario)["itens"][0]["usuario"] == "Carlos Caixa"


# ---------- origem ----------

def test_planilha_registra_origem_planilha(client):
    leite = criar_produto("Leite", codigo_barras="789", quantidade_estoque=10)
    produtos = "nome,codigo_barras,preco_venda,quantidade_estoque\nLeite,789,5,12\nNovo,790,2,7\n"
    client.post("/importar?modulo=produtos", data={"arquivo": (BytesIO(produtos.encode()), "p.csv")},
                content_type="multipart/form-data")
    vendas = f"id_produto,quantidade\n{leite.id_produto},3\n"
    client.post("/importar?modulo=vendas", data={"arquivo": (BytesIO(vendas.encode()), "v.csv")},
                content_type="multipart/form-data")

    da_planilha = historico(client, origem="planilha")["itens"]
    assert sorted((m["produto_nome"], m["tipo"], m["quantidade"]) for m in da_planilha) == [
        ("Leite", "ajuste_entrada", 2),
        ("Leite", "venda", 3),
        ("Novo", "saldo_inicial", 7),
    ]


def test_erp_registra_origem_erp(client):
    client.post("/erp/importar", json={
        "produtos": [{"codigo_barras": "111", "nome": "Arroz", "preco_venda": 25, "quantidade_estoque": 10}],
        "vendas": [{"codigo_barras": "111", "quantidade": 3}],
    })
    assert resumo(historico(client, origem="erp")["itens"]) == [("saldo_inicial", 10, 10), ("venda", 3, 7)]


# ---------- historico antigo ----------

def test_preenche_o_historico_antigo_uma_vez_so(banco):
    # como estava o banco antes desta etapa: lotes e vendas, sem nenhum registro de movimentacao
    p = Produto(nome="Leite", preco_venda=5, quantidade_estoque=8)
    db.session.add(p)
    db.session.flush()
    db.session.add(Lote(produto=p, quantidade_inicial=10, quantidade_atual=8, data_entrada=dia(-5), origem="inicial"))
    db.session.add(Venda(id_produto=p.id_produto, quantidade=2, data_venda=dia(-1)))
    db.session.commit()

    assert preencher_historico() == 2
    assert preencher_historico() == 0  # nao duplica
    registros = MovimentacaoEstoque.query.order_by(MovimentacaoEstoque.id_movimentacao).all()
    assert [(m.tipo, m.quantidade, m.origem, m.saldo_produto_apos) for m in registros] == [
        ("saldo_inicial", 10, "historico", None),
        ("venda", 2, "historico", None),
    ]
    assert registros[1].data_hora == datetime.combine(dia(-1), datetime.min.time())


def test_estoque_inicial_criado_ao_subir_entra_como_sistema(banco):
    db.session.add(Produto(nome="Antigo", preco_venda=5, quantidade_estoque=6))
    db.session.commit()
    preencher_historico()
    criar_lotes_iniciais()
    m = MovimentacaoEstoque.query.one()
    assert (m.tipo, m.quantidade, m.origem, m.saldo_produto_apos) == ("saldo_inicial", 6, "sistema", 6)


# ---------- consulta ----------

def test_filtros_e_paginacao(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    arroz = criar_produto("Arroz", quantidade_estoque=10)
    for _ in range(3):
        client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 1})
    client.post("/vendas", json={"id_produto": arroz.id_produto, "quantidade": 1})

    assert historico(client)["total"] == 6
    assert historico(client, id_produto=leite.id_produto)["total"] == 4
    assert historico(client, tipo="venda")["total"] == 4
    assert historico(client, tipo="venda", id_produto=arroz.id_produto)["total"] == 1

    pagina1 = historico(client, limite=4)
    pagina2 = historico(client, limite=4, pagina=2)
    assert (len(pagina1["itens"]), len(pagina2["itens"]), pagina2["pagina"]) == (4, 2, 2)
    ids = [m["id_movimentacao"] for m in pagina1["itens"] + pagina2["itens"]]
    assert ids == sorted(ids, reverse=True)  # mais recente primeiro, sem repetir


def test_filtro_por_lote(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    lote_novo = entrada(client, leite, 5, data_validade=dia(1).isoformat()).get_json()["lote"]
    client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 2})
    assert resumo(historico(client, id_lote=lote_novo["id_lote"])["itens"]) == [("entrada", 5, 15), ("venda", 2, 13)]


def test_filtro_por_periodo(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    antigo = MovimentacaoEstoque(id_produto=leite.id_produto, tipo="entrada", quantidade=1, origem="manual",
                                 data_hora=datetime.now() - timedelta(days=40))
    db.session.add(antigo)
    db.session.commit()
    hoje = date.today().isoformat()
    assert historico(client, inicio=hoje, fim=hoje)["total"] == 1  # o dia de hoje conta inteiro
    assert historico(client, inicio=dia(-60).isoformat(), fim=dia(-30).isoformat())["total"] == 1
    assert historico(client)["total"] == 2


def test_resposta_traz_os_nomes_dos_tipos_e_origens(client):
    corpo = historico(client)
    assert corpo["tipos"]["ajuste_saida"] == "Ajuste (saída)"
    assert corpo["origens"]["erp"] == "ERP"
    assert corpo["itens"] == [] and corpo["total"] == 0


@pytest.mark.parametrize("filtros, erro", [
    ({"tipo": "roubo"}, "tipo inválido"),
    ({"origem": "email"}, "origem inválida"),
    ({"id_produto": "abc"}, "id_produto tem que ser número"),
    ({"inicio": "2026-10-10", "fim": "2026-10-01"}, "a data de início tem que ser antes da data de fim"),
    ({"inicio": "10/10/2026"}, "data tem que ser aaaa-mm-dd"),
    ({"pagina": 0}, "pagina tem que ser 1 ou mais"),
    ({"limite": 500}, "limite tem que ser entre 1 e 200"),
    ({"limite": 0}, "limite tem que ser entre 1 e 200"),
])
def test_filtro_invalido(client, filtros, erro):
    r = client.get("/movimentacoes", query_string=filtros)
    assert r.status_code == 400
    assert r.get_json()["erro"].startswith(erro)


def test_excluir_produto_sem_venda_apaga_o_historico_dele(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    entrada(client, leite, 5)
    assert client.delete(f"/produtos/{leite.id_produto}").status_code == 204
    assert MovimentacaoEstoque.query.count() == 0


def test_fim_maximo_do_calendario_nao_estoura(client):
    assert client.get("/movimentacoes?fim=9999-12-31").status_code == 200


def test_consulta_paginada_nao_busca_relacoes_por_registro(client):
    from sqlalchemy import event
    from services.listar_movimentacoes_service import ListarMovimentacoesService

    for nome in ["Leite", "Queijo", "Arroz"]:
        criar_produto(nome, quantidade_estoque=5)
    db.session.expire_all()
    consultas = []

    def contar(conn, cursor, sql, parametros, contexto, muitos):
        if sql.lstrip().upper().startswith("SELECT"):
            consultas.append(sql)

    event.listen(db.engine, "before_cursor_execute", contar)
    try:
        resposta = ListarMovimentacoesService().executar({})
    finally:
        event.remove(db.engine, "before_cursor_execute", contar)
    assert resposta["total"] == 3
    assert {i["produto_nome"] for i in resposta["itens"]} == {"Leite", "Queijo", "Arroz"}
    assert len(consultas) == 2  # contagem + página, com todas as relações
