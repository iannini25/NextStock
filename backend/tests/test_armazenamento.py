from datetime import datetime, timedelta
from io import BytesIO

import pytest
from sqlalchemy import create_engine, inspect, text

from models.database import db
from models.leitura_temperatura_model import LeituraTemperatura
from models.produto_model import Produto
from services.migracao_armazenamento import garantir_coluna_local_produto
from tests.fabricas import criar_produto

CHAVE_SENSOR = "chave-do-sensor-de-teste-1234567890"


def criar_local(client, nome="Geladeira laticínios", **campos):
    r = client.post("/locais-armazenamento", json={"nome": nome, "tipo": "refrigerado",
                                                   "temp_min": 0, "temp_max": 5, **campos})
    assert r.status_code == 201, r.get_json()
    return r.get_json()


def ler(client, local, temperatura, **extra):
    return client.post(f"/locais-armazenamento/{local['id_local']}/leituras", json={"temperatura": temperatura, **extra})


# leitura gravada direto no banco, com a hora que quiser (pra testar "sem leitura ha X horas")
def leitura_antiga(local, temperatura, horas_atras):
    db.session.add(LeituraTemperatura(id_local=local["id_local"], temperatura=temperatura,
                                      data_hora=datetime.now() - timedelta(hours=horas_atras), origem="manual"))
    db.session.commit()


def situacao(client, local):
    return client.get(f"/locais-armazenamento/{local['id_local']}").get_json()


def alertas(client, **params):
    r = client.get("/armazenamento/alertas", query_string=params)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def sensor(client_anonimo, local, temperatura, chave=CHAVE_SENSOR, **extra):
    return client_anonimo.post(f"/locais-armazenamento/{local['id_local']}/leituras",
                               json={"temperatura": temperatura, **extra}, headers={"X-Sensor-Key": chave})


# ---------- migracao da coluna nova em produto ----------

def test_migracao_cria_a_coluna_num_banco_antigo_e_pode_rodar_de_novo():
    engine = create_engine("sqlite://")
    with engine.begin() as c:
        c.execute(text("CREATE TABLE local_armazenamento (id_local INTEGER PRIMARY KEY)"))
        c.execute(text("CREATE TABLE produto (id_produto INTEGER PRIMARY KEY, nome VARCHAR(150))"))
        c.execute(text("INSERT INTO produto (nome) VALUES ('Leite')"))

    assert garantir_coluna_local_produto(engine) is True
    assert "id_local_armazenamento" in {col["name"] for col in inspect(engine).get_columns("produto")}
    assert garantir_coluna_local_produto(engine) is False  # segunda vez: nada a fazer
    with engine.connect() as c:
        assert c.execute(text("SELECT nome, id_local_armazenamento FROM produto")).all() == [("Leite", None)]


def test_banco_novo_ja_nasce_com_a_coluna(banco):
    assert garantir_coluna_local_produto(banco.engine) is False


# ---------- locais ----------

def test_cria_local_com_a_faixa(client):
    local = criar_local(client)
    assert (local["nome"], local["tipo"], local["temp_min"], local["temp_max"], local["ativo"]) == (
        "Geladeira laticínios", "refrigerado", 0.0, 5.0, True)


@pytest.mark.parametrize("tipo, faixa", [("congelado", (-25.0, -18.0)), ("ambiente", (15.0, 30.0))])
def test_sem_faixa_usa_a_sugerida_pro_tipo(client, tipo, faixa):
    r = client.post("/locais-armazenamento", json={"nome": "Local", "tipo": tipo})
    assert (r.get_json()["temp_min"], r.get_json()["temp_max"]) == faixa


@pytest.mark.parametrize("dados, erro", [
    ({"nome": ""}, "nome é obrigatório"),
    ({"nome": "X", "tipo": "estufa"}, "tipo tem que ser ambiente, refrigerado ou congelado"),
    ({"nome": "X", "temp_min": 5, "temp_max": 5}, "a temperatura mínima tem que ser menor que a máxima"),
    ({"nome": "X", "temp_min": "frio"}, "temperatura mínima precisa ser um número"),
    ({"nome": "X", "temp_min": -100}, "temperatura mínima tem que ficar entre -60 e 80 °C"),
])
def test_validacoes_do_local(client, dados, erro):
    r = client.post("/locais-armazenamento", json=dados)
    assert (r.status_code, r.get_json()) == (400, {"erro": erro})


def test_nome_repetido_sem_diferenciar_maiusculas(client):
    criar_local(client, "Freezer")
    r = client.post("/locais-armazenamento", json={"nome": "FREEZER", "tipo": "congelado"})
    assert (r.status_code, r.get_json()["erro"]) == (400, "já existe um local com esse nome")


def test_editar_e_desativar_e_reativar(client):
    local = criar_local(client)
    r = client.put(f"/locais-armazenamento/{local['id_local']}", json={"nome": "Geladeira 1", "tipo": "refrigerado",
                                                                        "temp_min": 1, "temp_max": 4})
    assert (r.get_json()["nome"], r.get_json()["temp_max"]) == ("Geladeira 1", 4.0)

    assert client.delete(f"/locais-armazenamento/{local['id_local']}").get_json()["ativo"] is False
    assert client.get("/locais-armazenamento").get_json() == []
    [inativo] = client.get("/locais-armazenamento?todos=1").get_json()
    assert inativo["status"] == "inativo"

    r = client.put(f"/locais-armazenamento/{local['id_local']}", json={"nome": "Geladeira 1", "ativo": True})
    assert r.get_json()["ativo"] is True


def test_local_que_nao_existe(client):
    assert client.get("/locais-armazenamento/99").status_code == 404
    assert client.put("/locais-armazenamento/99", json={"nome": "X"}).status_code == 404
    assert client.delete("/locais-armazenamento/99").status_code == 404
    assert client.get("/locais-armazenamento/99/leituras").status_code == 404
    assert client.post("/locais-armazenamento/99/leituras", json={"temperatura": 3}).status_code == 404


def test_usuario_comum_consulta_e_registra_leitura_mas_nao_configura(client, client_usuario):
    local = criar_local(client)
    assert client_usuario.get("/locais-armazenamento").status_code == 200
    assert client_usuario.get(f"/locais-armazenamento/{local['id_local']}").status_code == 200
    assert ler(client_usuario, local, 3).status_code == 201
    assert client_usuario.post("/locais-armazenamento", json={"nome": "Outro"}).status_code == 403
    assert client_usuario.put(f"/locais-armazenamento/{local['id_local']}", json={"nome": "Y"}).status_code == 403
    assert client_usuario.delete(f"/locais-armazenamento/{local['id_local']}").status_code == 403


# ---------- leituras ----------

def test_leitura_dentro_da_faixa(client, admin):
    local = criar_local(client)
    r = ler(client, local, 3.46, umidade="70,5")
    assert r.status_code == 201
    leitura = r.get_json()["leitura"]
    assert (leitura["temperatura"], leitura["umidade"], leitura["origem"], leitura["usuario"]) == (3.5, 70.5, "manual", "Admin")
    assert leitura["fora_da_faixa"] is False
    assert r.get_json()["local"]["status"] == "ok"


def test_leitura_acima_do_maximo(client):
    local = criar_local(client)
    r = ler(client, local, 9)
    estado = r.get_json()["local"]
    assert (estado["status"], estado["prioridade"]) == ("fora_da_faixa", "alta")
    assert "9.0 °C" in estado["mensagem"] and "4.0 °C acima do máximo" in estado["mensagem"]
    assert r.get_json()["leitura"]["fora_da_faixa"] is True


def test_leitura_abaixo_do_minimo(client):
    local = criar_local(client)
    assert "2.0 °C abaixo do mínimo" in ler(client, local, -2).get_json()["local"]["mensagem"]


def test_voltou_pra_faixa_volta_pra_ok(client):
    local = criar_local(client)
    ler(client, local, 9)
    ler(client, local, 4)
    assert situacao(client, local)["status"] == "ok"


@pytest.mark.parametrize("dados, erro", [
    ({}, "temperatura é obrigatória"),
    ({"temperatura": "quente"}, "temperatura precisa ser um número"),
    ({"temperatura": 200}, "temperatura tem que ficar entre -60 e 80 °C"),
    ({"temperatura": 3, "umidade": 120}, "umidade tem que ficar entre 0 e 100%"),
    ({"temperatura": 3, "data_hora": "amanha"}, "data_hora tem que ser aaaa-mm-ddThh:mm:ss"),
    ({"temperatura": 3, "data_hora": (datetime.now() + timedelta(hours=2)).isoformat()}, "data_hora não pode ser no futuro"),
])
def test_validacoes_da_leitura(client, dados, erro):
    local = criar_local(client)
    r = client.post(f"/locais-armazenamento/{local['id_local']}/leituras", json=dados)
    assert (r.status_code, r.get_json()) == (400, {"erro": erro})


def test_local_desativado_nao_recebe_leitura(client):
    local = criar_local(client)
    client.delete(f"/locais-armazenamento/{local['id_local']}")
    r = ler(client, local, 3)
    assert (r.status_code, r.get_json()["erro"]) == (400, "esse local está desativado")


def test_historico_da_mais_nova_pra_mais_antiga_com_filtros(client):
    local = criar_local(client)
    ler(client, local, 2, data_hora=(datetime.now() - timedelta(days=3)).isoformat(timespec="seconds"))
    ler(client, local, 3, data_hora=(datetime.now() - timedelta(hours=1)).isoformat(timespec="seconds"))
    ler(client, local, 4)
    url = f"/locais-armazenamento/{local['id_local']}/leituras"
    assert [l["temperatura"] for l in client.get(url).get_json()] == [4.0, 3.0, 2.0]
    assert [l["temperatura"] for l in client.get(url + "?limite=2").get_json()] == [4.0, 3.0]
    hoje = datetime.now().date().isoformat()
    assert [l["temperatura"] for l in client.get(url + f"?inicio={hoje}").get_json()][-1] != 2.0
    assert client.get(url + "?limite=0").status_code == 400


# ---------- sensor (X-Sensor-Key) ----------

def test_sensor_com_a_chave_certa_registra_sem_login(client, client_anonimo, monkeypatch):
    monkeypatch.setenv("SENSOR_API_KEY", CHAVE_SENSOR)
    local = criar_local(client)
    r = sensor(client_anonimo, local, 4.2, umidade=60)
    assert r.status_code == 201, r.get_json()
    assert (r.get_json()["leitura"]["origem"], r.get_json()["leitura"]["usuario"]) == ("sensor", None)


def test_sensor_com_chave_errada(client, client_anonimo, monkeypatch):
    monkeypatch.setenv("SENSOR_API_KEY", CHAVE_SENSOR)
    local = criar_local(client)
    r = sensor(client_anonimo, local, 4, chave="errada")
    assert (r.status_code, r.get_json()) == (401, {"erro": "chave do sensor inválida"})
    assert LeituraTemperatura.query.count() == 0


def test_sem_chave_e_sem_login_e_401(client, client_anonimo, monkeypatch):
    monkeypatch.setenv("SENSOR_API_KEY", CHAVE_SENSOR)
    local = criar_local(client)
    r = client_anonimo.post(f"/locais-armazenamento/{local['id_local']}/leituras", json={"temperatura": 4})
    assert r.status_code == 401


def test_sensor_sem_chave_configurada_na_api(client, client_anonimo, monkeypatch):
    monkeypatch.delenv("SENSOR_API_KEY", raising=False)
    local = criar_local(client)
    r = sensor(client_anonimo, local, 4, chave="qualquer")
    assert r.status_code == 401
    assert r.get_json()["erro"].startswith("sensor não configurado")


def test_chave_do_sensor_so_abre_a_rota_de_leitura(client, client_anonimo, monkeypatch):
    monkeypatch.setenv("SENSOR_API_KEY", CHAVE_SENSOR)
    local = criar_local(client)
    cabecalho = {"X-Sensor-Key": CHAVE_SENSOR}
    assert client_anonimo.get("/locais-armazenamento", headers=cabecalho).status_code == 401
    assert client_anonimo.get(f"/locais-armazenamento/{local['id_local']}/leituras", headers=cabecalho).status_code == 401
    assert client_anonimo.post("/locais-armazenamento", json={"nome": "X"}, headers=cabecalho).status_code == 401
    assert client_anonimo.get("/produtos", headers=cabecalho).status_code == 401


# ---------- alertas ----------

def test_local_novo_sem_leitura_e_alerta_media(client):
    local = criar_local(client)
    [alerta] = alertas(client)
    assert (alerta["id_local"], alerta["status"], alerta["prioridade"]) == (local["id_local"], "sem_leitura", "media")
    assert "nenhuma leitura" in alerta["mensagem"]


def test_leitura_recente_ok_nao_alerta(client):
    local = criar_local(client)
    ler(client, local, 3)
    assert alertas(client) == []


def test_leitura_velha_vira_sem_leitura_conforme_as_horas(client):
    local = criar_local(client)
    leitura_antiga(local, 3, horas_atras=13)
    [alerta] = alertas(client)
    assert alerta["status"] == "sem_leitura"
    assert "sem leitura há 13 h" in alerta["mensagem"]
    assert alertas(client, horas=24) == []


def test_fora_da_faixa_mostra_produtos_e_valor_em_risco(client):
    local = criar_local(client)
    leite = client.post("/produtos", json={"nome": "Leite", "preco_venda": 5, "preco_custo": 3, "quantidade_estoque": 10,
                                           "id_local_armazenamento": local["id_local"]}).get_json()
    client.post("/lotes", json={"id_produto": leite["id_produto"], "quantidade": 5, "custo_unitario": 4})
    criar_produto("Arroz", quantidade_estoque=50)  # nao esta na geladeira
    ler(client, local, 9)

    [alerta] = alertas(client)
    assert alerta["prioridade"] == "alta"
    assert alerta["produtos"] == [{"id_produto": leite["id_produto"], "nome": "Leite", "unidade": "UN",
                                   "quantidade_estoque": 15, "valor": 50.0}]  # 10 x 3 + 5 x 4
    assert alerta["valor_em_risco"] == 50.0
    assert "R$ 50.00 em produtos em risco" in alerta["mensagem"]


def test_alta_primeiro_e_local_desativado_fica_fora(client):
    sem = criar_local(client, "A sem leitura")
    quente = criar_local(client, "B quente")
    ler(client, quente, 10)
    desligado = criar_local(client, "C desligado")
    client.delete(f"/locais-armazenamento/{desligado['id_local']}")
    assert [a["nome"] for a in alertas(client)] == ["B quente", "A sem leitura"]
    assert sem["id_local"] != quente["id_local"]


def test_horas_invalida(client):
    assert client.get("/armazenamento/alertas?horas=0").status_code == 400


def test_resumo_conta_temperatura_no_selo(client):
    quente = criar_local(client, "Quente")
    ler(client, quente, 10)
    criar_local(client, "Sem leitura")
    resumo = client.get("/alertas/resumo").get_json()
    assert resumo["temperatura"] == 2
    assert resumo["prioridade_alta"] == 1
    assert resumo["total"] == resumo["vencendo"] + resumo["falta"] + resumo["excesso"] + 2


def test_lista_de_locais_mostra_status_e_ultima_leitura(client):
    local = criar_local(client)
    ler(client, local, 4)
    [item] = client.get("/locais-armazenamento").get_json()
    assert (item["status"], item["nome_status"], item["ultima_leitura"]["temperatura"]) == ("ok", "OK", 4.0)
    assert item["quantidade_produtos"] == 0


# ---------- produto ligado ao local ----------

def test_produto_criado_com_local(client):
    local = criar_local(client)
    p = client.post("/produtos", json={"nome": "Iogurte", "preco_venda": 3, "id_local_armazenamento": local["id_local"]}).get_json()
    assert (p["id_local_armazenamento"], p["local_armazenamento"]) == (local["id_local"], "Geladeira laticínios")
    detalhe = situacao(client, local)
    assert [x["nome"] for x in detalhe["produtos"]] == ["Iogurte"]


def test_editar_sem_o_campo_mantem_o_local(client):
    local = criar_local(client)
    p = client.post("/produtos", json={"nome": "Leite", "preco_venda": 5, "id_local_armazenamento": local["id_local"]}).get_json()
    # o formulario antigo nao manda o campo
    r = client.put(f"/produtos/{p['id_produto']}", json={"nome": "Leite Integral", "preco_venda": 6})
    assert (r.get_json()["nome"], r.get_json()["id_local_armazenamento"]) == ("Leite Integral", local["id_local"])


def test_editar_com_null_tira_do_local(client):
    local = criar_local(client)
    p = client.post("/produtos", json={"nome": "Leite", "preco_venda": 5, "id_local_armazenamento": local["id_local"]}).get_json()
    r = client.put(f"/produtos/{p['id_produto']}", json={"nome": "Leite", "preco_venda": 5, "id_local_armazenamento": None})
    assert r.get_json()["id_local_armazenamento"] is None


def test_local_invalido_no_produto(client):
    r = client.post("/produtos", json={"nome": "X", "preco_venda": 5, "id_local_armazenamento": 99})
    assert (r.status_code, r.get_json()["erro"]) == (400, "local de armazenamento não existe")


def test_local_desativado_continua_no_produto_mas_nao_pode_ser_escolhido(client):
    local = criar_local(client)
    p = client.post("/produtos", json={"nome": "Leite", "preco_venda": 5, "id_local_armazenamento": local["id_local"]}).get_json()
    client.delete(f"/locais-armazenamento/{local['id_local']}")
    # editar mandando o mesmo local (desativado) nao da erro
    r = client.put(f"/produtos/{p['id_produto']}", json={"nome": "Leite", "preco_venda": 6,
                                                        "id_local_armazenamento": local["id_local"]})
    assert r.status_code == 200
    r = client.post("/produtos", json={"nome": "Outro", "preco_venda": 5, "id_local_armazenamento": local["id_local"]})
    assert (r.status_code, r.get_json()["erro"]) == (400, "esse local de armazenamento está desativado")


def test_importar_planilha_e_erp_mantem_o_local(client):
    local = criar_local(client)
    leite = criar_produto("Leite", codigo_barras="789", quantidade_estoque=10, id_local_armazenamento=local["id_local"])
    arroz = criar_produto("Arroz", codigo_barras="111", quantidade_estoque=5, id_local_armazenamento=local["id_local"])

    csv = "nome,codigo_barras,preco_venda,quantidade_estoque\nLeite Integral,789,6.5,12\n"
    client.post("/importar?modulo=produtos", data={"arquivo": (BytesIO(csv.encode()), "p.csv")},
                content_type="multipart/form-data")
    client.post("/erp/importar", json={"produtos": [{"codigo_barras": "111", "nome": "Arroz 5kg", "preco_venda": 25,
                                                     "quantidade_estoque": 8}]})

    db.session.expire_all()
    assert (Produto.buscar_por_id(leite.id_produto).nome, Produto.buscar_por_id(leite.id_produto).id_local_armazenamento) == (
        "Leite Integral", local["id_local"])
    assert (Produto.buscar_por_id(arroz.id_produto).nome, Produto.buscar_por_id(arroz.id_produto).id_local_armazenamento) == (
        "Arroz 5kg", local["id_local"])


def test_produto_atualizar_sem_id_local_mantem(client):
    local = criar_local(client)
    p = criar_produto("Leite", id_local_armazenamento=local["id_local"])
    p.atualizar("Leite 2", None, None, 3, 5, 0, 0, "UN", None)
    assert p.id_local_armazenamento == local["id_local"]
    p.atualizar("Leite 3", None, None, 3, 5, 0, 0, "UN", None, id_local=None)
    assert p.id_local_armazenamento is None
