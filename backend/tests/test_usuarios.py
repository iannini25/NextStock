import pytest

from models.usuario_model import Usuario
from tests.fabricas import criar_empresa, criar_usuario

NOVO = {"nome": "João Caixa", "email": "Joao@Loja.com", "senha": "senha1234"}


def test_lista_vazia(client):
    r = client.get("/usuarios")
    assert r.status_code == 200
    assert r.get_json() == []


def test_criar_exige_empresa_configurada(client):
    r = client.post("/usuarios", json=NOVO)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "configure a empresa antes de cadastrar usuários"}


def test_cria_usuario_com_perfil_padrao(client):
    empresa = criar_empresa()
    r = client.post("/usuarios", json=NOVO)
    assert r.status_code == 201
    u = r.get_json()
    assert u["nome"] == "João Caixa"
    assert u["email"] == "joao@loja.com"
    assert u["perfil"] == "usuario"
    assert u["ativo"] is True
    assert u["id_empresa"] == empresa.id_empresa
    assert "senha" not in u and "senha_hash" not in u
    salvo = Usuario.buscar_por_email("joao@loja.com")
    assert salvo.senha_hash != "senha1234"
    assert salvo.conferir_senha("senha1234")


def test_cria_admin(client):
    criar_empresa()
    r = client.post("/usuarios", json={**NOVO, "perfil": "admin"})
    assert r.get_json()["perfil"] == "admin"


@pytest.mark.parametrize("mudanca, erro", [
    ({"nome": ""}, "nome é obrigatório"),
    ({"email": ""}, "e-mail é obrigatório"),
    ({"email": "joao@loja"}, "e-mail inválido"),
    ({"senha": "curta"}, "senha tem que ter pelo menos 8 caracteres"),
    ({"senha": None}, "senha tem que ter pelo menos 8 caracteres"),
    ({"perfil": "gerente"}, "perfil tem que ser admin ou usuario"),
])
def test_cria_usuario_invalido(client, mudanca, erro):
    criar_empresa()
    r = client.post("/usuarios", json={**NOVO, **mudanca})
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
    assert Usuario.query.count() == 0


def test_email_repetido_mesmo_com_maiusculas(client):
    criar_usuario(email="maria@loja.com")
    r = client.post("/usuarios", json={**NOVO, "email": "MARIA@loja.com"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já existe usuário com esse e-mail"}


def test_lista_em_ordem_de_nome_sem_senha(client):
    criar_usuario("Zeca", "zeca@loja.com")
    criar_usuario("Ana", "ana@loja.com", perfil="admin")
    lista = client.get("/usuarios").get_json()
    assert [u["nome"] for u in lista] == ["Ana", "Zeca"]
    assert all("senha_hash" not in u for u in lista)


def test_atualiza_dados_sem_trocar_a_senha(client):
    u = criar_usuario("Maria", "maria@loja.com")
    hash_antes = u.senha_hash
    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": "Maria Souza", "email": "maria.souza@loja.com", "perfil": "admin"})
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Maria Souza"
    assert r.get_json()["email"] == "maria.souza@loja.com"
    assert r.get_json()["perfil"] == "admin"
    assert Usuario.buscar_por_id(u.id_usuario).senha_hash == hash_antes


def test_atualiza_senha(client):
    u = criar_usuario(senha="senha-antiga")
    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": u.nome, "email": u.email, "senha": "senha-nova-123"})
    assert r.status_code == 200
    salvo = Usuario.buscar_por_id(u.id_usuario)
    assert salvo.conferir_senha("senha-nova-123")
    assert not salvo.conferir_senha("senha-antiga")


def test_senha_curta_na_edicao_nao_muda_nada(client):
    u = criar_usuario("Maria", senha="senha-antiga")
    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": "Outro nome", "email": u.email, "senha": "123"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "senha tem que ter pelo menos 8 caracteres"}
    salvo = Usuario.buscar_por_id(u.id_usuario)
    assert salvo.nome == "Maria"
    assert salvo.conferir_senha("senha-antiga")


def test_perfil_omitido_na_edicao_fica_como_estava(client):
    u = criar_usuario(perfil="admin")
    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": u.nome, "email": u.email})
    assert r.get_json()["perfil"] == "admin"


def test_atualiza_com_email_de_outro_usuario(client):
    criar_usuario("Ana", "ana@loja.com")
    maria = criar_usuario("Maria", "maria@loja.com")
    r = client.put(f"/usuarios/{maria.id_usuario}", json={"nome": "Maria", "email": "ANA@loja.com"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já existe usuário com esse e-mail"}


def test_atualiza_mantendo_o_proprio_email(client):
    maria = criar_usuario("Maria", "maria@loja.com")
    r = client.put(f"/usuarios/{maria.id_usuario}", json={"nome": "Maria S.", "email": "maria@loja.com"})
    assert r.status_code == 200


def test_ativo_precisa_ser_booleano(client):
    u = criar_usuario()
    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": u.nome, "email": u.email, "ativo": "sim"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "ativo tem que ser true ou false"}


def test_atualiza_inexistente(client):
    r = client.put("/usuarios/999", json={"nome": "X", "email": "x@loja.com"})
    assert r.status_code == 404
    assert r.get_json() == {"erro": "usuário não encontrado"}


def test_desativa_sem_apagar_e_reativa(client):
    u = criar_usuario("Maria")
    assert client.delete(f"/usuarios/{u.id_usuario}").status_code == 204

    lista = client.get("/usuarios").get_json()
    assert len(lista) == 1
    assert lista[0]["ativo"] is False

    r = client.put(f"/usuarios/{u.id_usuario}", json={"nome": "Maria", "email": u.email, "ativo": True})
    assert r.get_json()["ativo"] is True


def test_desativa_inexistente(client):
    r = client.delete("/usuarios/999")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "usuário não encontrado"}
