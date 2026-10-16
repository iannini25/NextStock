import copy

import pytest

from models.empresa_model import Empresa
from models.usuario_model import Usuario
from tests.fabricas import criar_empresa

SETUP = {
    "empresa": {
        "nome": "Mercado Bom Preço LTDA",
        "nome_fantasia": "Bom Preço",
        "cnpj": "12.345.678/0001-90",
        "email": "Contato@BomPreco.com",
        "telefone": "(11) 99999-0000",
    },
    "admin": {"nome": "Ana Admin", "email": "Ana@BomPreco.com", "senha": "senhaforte123"},
}


def setup_com(**mudancas):
    dados = copy.deepcopy(SETUP)
    for caminho, valor in mudancas.items():
        parte, campo = caminho.split("__")
        dados[parte][campo] = valor
    return dados


def test_status_antes_e_depois_da_configuracao(client):
    assert client.get("/setup/status").get_json() == {"configurado": False}
    assert client.post("/setup", json=SETUP).status_code == 201
    assert client.get("/setup/status").get_json() == {"configurado": True}


def test_configuracao_cria_empresa_e_admin(client):
    r = client.post("/setup", json=SETUP)
    assert r.status_code == 201
    corpo = r.get_json()

    assert corpo["empresa"]["nome"] == "Mercado Bom Preço LTDA"
    assert corpo["empresa"]["nome_fantasia"] == "Bom Preço"
    assert corpo["empresa"]["cnpj"] == "12345678000190"
    assert corpo["empresa"]["email"] == "contato@bompreco.com"
    assert corpo["empresa"]["telefone"] == "(11) 99999-0000"

    admin = corpo["admin"]
    assert admin["nome"] == "Ana Admin"
    assert admin["email"] == "ana@bompreco.com"
    assert admin["perfil"] == "admin"
    assert admin["ativo"] is True
    assert admin["id_empresa"] == corpo["empresa"]["id_empresa"]
    assert "senha" not in admin and "senha_hash" not in admin

    salvo = Usuario.buscar_por_email("ana@bompreco.com")
    assert salvo.senha_hash != "senhaforte123"
    assert salvo.conferir_senha("senhaforte123")
    assert not salvo.conferir_senha("outra-senha")


def test_admin_da_configuracao_sempre_e_admin(client):
    r = client.post("/setup", json=setup_com(admin__perfil="usuario"))
    assert r.get_json()["admin"]["perfil"] == "admin"


def test_configuracao_so_uma_vez(client):
    client.post("/setup", json=SETUP)
    r = client.post("/setup", json=setup_com(admin__email="outro@loja.com"))
    assert r.status_code == 409
    assert r.get_json() == {"erro": "a empresa já foi configurada"}
    assert Empresa.query.count() == 1
    assert Usuario.query.count() == 1


@pytest.mark.parametrize("dados, erro", [
    (setup_com(empresa__nome=""), "nome da empresa é obrigatório"),
    (setup_com(empresa__cnpj="1234567800019"), "CNPJ tem que ter 14 números"),
    (setup_com(empresa__email="contato@"), "e-mail inválido"),
    (setup_com(empresa__nome_fantasia="x" * 151), "nome fantasia pode ter no máximo 150 caracteres"),
    (setup_com(admin__nome="  "), "nome é obrigatório"),
    (setup_com(admin__email=""), "e-mail é obrigatório"),
    (setup_com(admin__email="ana bompreco.com"), "e-mail inválido"),
    (setup_com(admin__senha="1234567"), "senha tem que ter pelo menos 8 caracteres"),
    ({"empresa": SETUP["empresa"]}, "mande os dados da empresa e do administrador"),
])
def test_configuracao_invalida_nao_grava_nada(client, dados, erro):
    r = client.post("/setup", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
    assert Empresa.query.count() == 0
    assert Usuario.query.count() == 0


def test_busca_empresa_antes_da_configuracao(client):
    r = client.get("/empresa")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "empresa ainda não configurada"}


def test_busca_empresa(client):
    criar_empresa("Padaria Pão Quente", cnpj="11222333000144")
    r = client.get("/empresa")
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Padaria Pão Quente"
    assert r.get_json()["cnpj"] == "11222333000144"


def test_atualiza_empresa(client):
    criar_empresa("Nome antigo", nome_fantasia="Antiga", telefone="1111")
    r = client.put("/empresa", json={"nome": "Nome novo", "cnpj": "11.222.333/0001-44", "telefone": ""})
    assert r.status_code == 200
    empresa = r.get_json()
    assert empresa["nome"] == "Nome novo"
    assert empresa["cnpj"] == "11222333000144"
    assert empresa["nome_fantasia"] is None  # campo nao enviado fica vazio (a tela manda o form inteiro)
    assert empresa["telefone"] is None


def test_atualiza_empresa_invalida(client):
    criar_empresa()
    r = client.put("/empresa", json={"nome": ""})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "nome da empresa é obrigatório"}


def test_atualiza_empresa_antes_da_configuracao(client):
    r = client.put("/empresa", json={"nome": "X"})
    assert r.status_code == 404
