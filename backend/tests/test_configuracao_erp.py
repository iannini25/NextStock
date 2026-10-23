import json

import pytest
from cryptography.fernet import Fernet

from models.configuracao_erp_model import ConfiguracaoErp
from services.cripto_service import CriptoService

CHAVE = "erp-chave-secreta-1a2b"
CONFIG = {"provedor": "generico", "url_base": "https://erp.minhaloja.com/api/", "chave_api": CHAVE}


def salvar(client, **mudancas):
    return client.put("/erp/configuracao", json={**CONFIG, **mudancas})


def test_sem_configuracao(client):
    r = client.get("/erp/configuracao")
    assert r.status_code == 200
    corpo = r.get_json()
    assert corpo["configurado"] is False
    assert corpo["possui_chave"] is False
    assert corpo["chave_mascarada"] is None
    assert corpo["provedores"] == {"generico": "ERP genérico (API REST)"}


def test_salva_e_devolve_a_chave_mascarada(client, admin):
    r = salvar(client)
    assert r.status_code == 200
    corpo = r.get_json()
    assert corpo["configurado"] is True
    assert corpo["provedor"] == "generico"
    assert corpo["url_base"] == "https://erp.minhaloja.com/api"  # sem a barra do fim
    assert corpo["ativo"] is True
    assert corpo["possui_chave"] is True
    assert corpo["chave_mascarada"] == "••••1a2b"
    assert corpo["atualizado_por"] == "Admin"
    assert corpo["atualizado_em"]
    assert client.get("/erp/configuracao").get_json()["chave_mascarada"] == "••••1a2b"


def test_chave_nunca_aparece_inteira_nas_respostas(client):
    respostas = [salvar(client), client.get("/erp/configuracao"), salvar(client, chave_api="")]
    for r in respostas:
        assert CHAVE not in json.dumps(r.get_json(), ensure_ascii=False)


def test_no_banco_a_chave_fica_criptografada(client):
    salvar(client)
    config = ConfiguracaoErp.query.one()
    assert CHAVE not in config.chave_criptografada
    assert CriptoService().descriptografar(config.chave_criptografada) == CHAVE


def test_primeira_vez_exige_a_chave(client):
    r = salvar(client, chave_api="")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "informe a chave da API do ERP"}
    assert ConfiguracaoErp.query.count() == 0


def test_editar_sem_chave_mantem_a_que_estava(client):
    salvar(client)
    r = salvar(client, url_base="https://outro-erp.com", chave_api="")
    assert r.get_json()["url_base"] == "https://outro-erp.com"
    assert r.get_json()["chave_mascarada"] == "••••1a2b"
    assert CriptoService().descriptografar(ConfiguracaoErp.query.one().chave_criptografada) == CHAVE


def test_trocar_a_chave(client):
    salvar(client)
    r = salvar(client, chave_api="nova-chave-9z9z")
    assert r.get_json()["chave_mascarada"] == "••••9z9z"
    assert ConfiguracaoErp.query.count() == 1  # atualiza, nao cria outra


def test_desativar_a_integracao(client):
    salvar(client)
    assert salvar(client, chave_api="", ativo=False).get_json()["ativo"] is False


@pytest.mark.parametrize("mudanca, erro", [
    ({"url_base": ""}, "informe a URL do ERP"),
    ({"url_base": "erp.minhaloja.com"}, "URL inválida: use o endereço completo, ex.: https://erp.minhaloja.com/api"),
    ({"url_base": "ftp://erp.com"}, "URL inválida: use o endereço completo, ex.: https://erp.minhaloja.com/api"),
    ({"url_base": "https://erp .com"}, "URL inválida: use o endereço completo, ex.: https://erp.minhaloja.com/api"),
    ({"provedor": "sap"}, "provedor inválido. use: generico"),
    ({"ativo": "sim"}, "ativo tem que ser true ou false"),
    ({"chave_api": "x" * 501}, "chave da API pode ter no máximo 500 caracteres"),
])
def test_configuracao_invalida(client, mudanca, erro):
    r = salvar(client, **mudanca)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
    assert ConfiguracaoErp.query.count() == 0


def test_remover_a_chave_mantem_a_url(client):
    salvar(client)
    r = client.delete("/erp/configuracao/chave")
    assert r.status_code == 200
    assert r.get_json()["possui_chave"] is False
    assert r.get_json()["chave_mascarada"] is None
    assert r.get_json()["url_base"] == "https://erp.minhaloja.com/api"
    assert ConfiguracaoErp.query.one().chave_criptografada is None


def test_remover_sem_configuracao(client):
    r = client.delete("/erp/configuracao/chave")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "integração com ERP ainda não configurada"}


def test_chave_curta_fica_toda_escondida(client):
    assert salvar(client, chave_api="abc").get_json()["chave_mascarada"] == "••••"


def test_sem_chave_de_criptografia_no_env_nao_grava(client, monkeypatch):
    monkeypatch.delenv("ERP_CHAVE_CRIPTOGRAFIA")
    r = salvar(client)
    assert r.status_code == 500
    erro = r.get_json()["erro"]
    assert erro.startswith("configure a ERP_CHAVE_CRIPTOGRAFIA no .env da API e reinicie a API")
    assert "secrets.token_hex(32)" in erro  # ja diz como gerar
    assert ConfiguracaoErp.query.count() == 0


@pytest.mark.parametrize("fraca", [
    "isso-nao-e-uma-chave",  # curta
    "1234567890" * 7,  # comprida mas repetitiva
    "a" * 64,
])
def test_chave_de_criptografia_fraca_no_env(client, monkeypatch, fraca):
    monkeypatch.setenv("ERP_CHAVE_CRIPTOGRAFIA", fraca)
    r = salvar(client)
    assert r.status_code == 500
    assert r.get_json()["erro"].startswith("a ERP_CHAVE_CRIPTOGRAFIA do .env da API é fraca")
    assert ConfiguracaoErp.query.count() == 0


def test_qualquer_texto_aleatorio_serve_de_chave(client, monkeypatch):
    import secrets

    monkeypatch.setenv("ERP_CHAVE_CRIPTOGRAFIA", secrets.token_hex(32))  # mesmo comando da SECRET_KEY
    assert salvar(client).get_json()["chave_mascarada"] == "••••1a2b"
    assert CriptoService().descriptografar(ConfiguracaoErp.query.one().chave_criptografada) == CHAVE


def test_trocaram_a_chave_de_criptografia_do_env(client, monkeypatch):
    salvar(client)
    monkeypatch.setenv("ERP_CHAVE_CRIPTOGRAFIA", Fernet.generate_key().decode())
    corpo = client.get("/erp/configuracao").get_json()
    assert corpo["possui_chave"] is True
    assert corpo["chave_mascarada"] is None
    assert "Cadastre a chave de novo" in corpo["aviso"]
    # cadastrar de novo resolve
    assert salvar(client, chave_api="chave-nova-1234").get_json()["chave_mascarada"] == "••••1234"


def test_sem_env_ainda_da_pra_ver_a_configuracao(client, monkeypatch):
    salvar(client)
    monkeypatch.delenv("ERP_CHAVE_CRIPTOGRAFIA")
    r = client.get("/erp/configuracao")
    assert r.status_code == 200
    assert r.get_json()["possui_chave"] is True
    assert r.get_json()["aviso"].startswith("configure a ERP_CHAVE_CRIPTOGRAFIA no .env da API")


def test_erp_importar_continua_igual(client):
    salvar(client)
    r = client.post("/erp/importar", json={"produtos": [{"codigo_barras": "1", "nome": "X", "preco_venda": 1}]})
    assert r.get_json()["produtos_criados"] == 1
