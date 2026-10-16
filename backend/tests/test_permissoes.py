import pytest

from models.usuario_model import Usuario
from services.atualizar_usuario_service import AtualizarUsuarioService
from services.desativar_usuario_service import DesativarUsuarioService
from tests.fabricas import criar_usuario
from tests.test_rotas import ROTAS_PUBLICAS, rotas_registradas

# so o administrador pode: usuarios, editar a empresa, ERP, importacao de planilha e exclusoes.
# o usuario comum faz a operacao do dia a dia (consultar, vender, cadastrar e editar).
ROTAS_SO_ADMIN = {
    ("/usuarios", "GET"),
    ("/usuarios", "POST"),
    ("/usuarios/<int:id>", "PUT"),
    ("/usuarios/<int:id>", "DELETE"),
    ("/empresa", "PUT"),
    ("/erp/importar", "POST"),
    ("/erp/configuracao", "GET"),
    ("/erp/configuracao", "PUT"),
    ("/erp/configuracao/chave", "DELETE"),
    ("/erp/testar-conexao", "POST"),
    ("/erp/sincronizar", "POST"),
    ("/erp/sincronizacoes", "GET"),
    ("/importar/modelo", "GET"),
    ("/importar", "POST"),
    ("/produtos/<int:id>", "DELETE"),
    ("/categorias/<int:id>", "DELETE"),
    ("/eventos/<int:id>", "DELETE"),
    # etapa 13: locais de armazenamento sao configuracao (leitura de temperatura todo mundo registra)
    ("/locais-armazenamento", "POST"),
    ("/locais-armazenamento/<int:id>", "PUT"),
    ("/locais-armazenamento/<int:id>", "DELETE"),
}

ROTAS_COMUNS = sorted(set(rotas_registradas()) - ROTAS_PUBLICAS - ROTAS_SO_ADMIN)


def chamar(client, rota, metodo):
    return client.open(rota.replace("<int:id>", "999"), method=metodo, json={})


def test_lista_de_rotas_so_admin_existe():
    assert ROTAS_SO_ADMIN - set(rotas_registradas()) == set()


@pytest.mark.parametrize("rota, metodo", sorted(ROTAS_SO_ADMIN))
def test_usuario_comum_recebe_403_nas_rotas_de_admin(client_usuario, rota, metodo):
    r = chamar(client_usuario, rota, metodo)
    assert r.status_code == 403, f"{metodo} {rota}"
    assert r.get_json() == {"erro": "sem permissão para esta ação"}


@pytest.mark.parametrize("rota, metodo", sorted(ROTAS_SO_ADMIN))
def test_admin_passa_nas_rotas_de_admin(client, rota, metodo):
    assert chamar(client, rota, metodo).status_code not in (401, 403), f"{metodo} {rota}"


# toda rota nova que nao for marcada como so admin fica liberada pros dois perfis
@pytest.mark.parametrize("rota, metodo", ROTAS_COMUNS)
def test_usuario_comum_passa_nas_demais_rotas(client_usuario, rota, metodo):
    assert chamar(client_usuario, rota, metodo).status_code not in (401, 403), f"{metodo} {rota}"


def test_usuario_comum_faz_a_operacao_do_dia_a_dia(client_usuario):
    cat = client_usuario.post("/categorias", json={"nome": "Bebidas"})
    assert cat.status_code == 201
    prod = client_usuario.post("/produtos", json={"nome": "Suco", "preco_venda": 6, "quantidade_estoque": 10,
                                                   "id_categoria": cat.get_json()["id_categoria"]})
    assert prod.status_code == 201
    id_produto = prod.get_json()["id_produto"]
    editado = {"nome": "Suco de uva", "preco_venda": 7, "quantidade_estoque": 10}  # o PUT manda o form inteiro
    assert client_usuario.put(f"/produtos/{id_produto}", json=editado).status_code == 200
    assert client_usuario.post("/vendas", json={"id_produto": id_produto, "quantidade": 2}).status_code == 201
    assert client_usuario.get("/empresa").status_code == 200  # ve a empresa, mas nao edita
    assert client_usuario.delete(f"/produtos/{id_produto}").status_code == 403


def test_admin_nao_pode_se_desativar(client, admin):
    r = client.delete(f"/usuarios/{admin.id_usuario}")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "você não pode desativar o seu próprio usuário"}
    assert Usuario.buscar_por_id(admin.id_usuario).ativo is True


def test_admin_nao_pode_se_desativar_pela_edicao(client, admin):
    r = client.put(f"/usuarios/{admin.id_usuario}", json={"nome": "Admin", "email": admin.email, "ativo": False})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "você não pode desativar o seu próprio usuário"}


def test_admin_nao_pode_tirar_o_proprio_acesso(client, admin):
    r = client.put(f"/usuarios/{admin.id_usuario}", json={"nome": "Admin", "email": admin.email, "perfil": "usuario"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "você não pode tirar o seu próprio acesso de administrador"}
    assert Usuario.buscar_por_id(admin.id_usuario).perfil == "admin"


def test_admin_pode_editar_os_proprios_dados(client, admin):
    r = client.put(f"/usuarios/{admin.id_usuario}", json={"nome": "Admin Chefe", "email": admin.email})
    assert r.status_code == 200
    assert r.get_json()["perfil"] == "admin"


def test_admin_pode_rebaixar_e_desativar_outro_admin(client):
    outro = criar_usuario("Bia", "bia@loja.com", perfil="admin")
    r = client.put(f"/usuarios/{outro.id_usuario}", json={"nome": "Bia", "email": outro.email, "perfil": "usuario"})
    assert r.get_json()["perfil"] == "usuario"
    assert client.delete(f"/usuarios/{outro.id_usuario}").status_code == 204


# a regra do ultimo admin tambem vale fora da tela (ex.: chamada direta do service)
def test_nunca_fica_sem_admin_ativo(admin):
    with pytest.raises(ValueError, match="pelo menos um administrador ativo"):
        AtualizarUsuarioService().executar(admin.id_usuario, {"nome": "Admin", "email": admin.email, "perfil": "usuario"})
    with pytest.raises(ValueError, match="pelo menos um administrador ativo"):
        DesativarUsuarioService().executar(admin.id_usuario)
    assert Usuario.buscar_por_id(admin.id_usuario).perfil == "admin"
    assert Usuario.buscar_por_id(admin.id_usuario).ativo is True


def test_usuario_comum_pode_ser_desativado_mesmo_sendo_o_unico(client):
    comum = criar_usuario("Carlos", "carlos2@loja.com")
    assert client.delete(f"/usuarios/{comum.id_usuario}").status_code == 204
