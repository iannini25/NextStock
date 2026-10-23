import socket
import urllib.error
import urllib.request
from datetime import datetime

import pytest

from services.erp.conector_erp import ErroErp
from services.erp.conector_generico import ConectorErpGenerico


class RespostaFalsa:
    def __init__(self, corpo):
        self.corpo = corpo

    def read(self):
        return self.corpo.encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


@pytest.fixture
def pedidos(monkeypatch):
    # guarda os pedidos feitos e responde o que o teste mandar
    estado = {"pedidos": [], "resposta": "[]", "erro": None}

    def urlopen_falso(req, timeout=None):
        estado["pedidos"].append((req, timeout))
        if estado["erro"]:
            raise estado["erro"]
        return RespostaFalsa(estado["resposta"])

    monkeypatch.setattr(urllib.request, "urlopen", urlopen_falso)
    return estado


def conector():
    return ConectorErpGenerico("https://erp.loja.com/api/", "chave-123")


def test_testar_conexao_manda_a_chave_e_chama_o_status(pedidos):
    pedidos["resposta"] = '{"status": "ok"}'
    assert conector().testar_conexao() == {"status": "ok"}
    req, timeout = pedidos["pedidos"][0]
    assert req.full_url == "https://erp.loja.com/api/status"  # sem barra dobrada
    assert req.get_header("Authorization") == "Bearer chave-123"
    assert timeout == 15


def test_buscar_com_e_sem_desde(pedidos):
    pedidos["resposta"] = '[{"codigo_barras": "1"}]'
    assert conector().buscar_produtos(None) == [{"codigo_barras": "1"}]
    assert pedidos["pedidos"][0][0].full_url == "https://erp.loja.com/api/produtos"

    conector().buscar_vendas(datetime(2026, 10, 16, 9, 30, 15, 999))
    assert pedidos["pedidos"][1][0].full_url == "https://erp.loja.com/api/vendas?desde=2026-10-16T09%3A30%3A15"


@pytest.mark.parametrize("erro, mensagem", [
    (urllib.error.HTTPError("u", 401, "Unauthorized", {}, None), "o ERP recusou a chave da API (HTTP 401)"),
    (urllib.error.HTTPError("u", 403, "Forbidden", {}, None), "o ERP recusou a chave da API (HTTP 403)"),
    (urllib.error.HTTPError("u", 404, "Not Found", {}, None), "endereço não encontrado no ERP (HTTP 404)"),
    (urllib.error.HTTPError("u", 500, "Erro", {}, None), "o ERP respondeu com erro (HTTP 500)"),
    (urllib.error.URLError(ConnectionRefusedError()), "não foi possível conectar ao ERP em https://erp.loja.com/api"),
    (urllib.error.URLError(socket.timeout()), "o ERP demorou mais de 15 segundos"),
    (TimeoutError(), "o ERP demorou mais de 15 segundos"),
    (ConnectionResetError(), "não foi possível conectar ao ERP"),
])
def test_falhas_viram_mensagem_clara(pedidos, erro, mensagem):
    pedidos["erro"] = erro
    with pytest.raises(ErroErp) as e:
        conector().testar_conexao()
    assert mensagem in str(e.value)


def test_resposta_que_nao_e_json(pedidos):
    pedidos["resposta"] = "<html>erro</html>"
    with pytest.raises(ErroErp, match="não é JSON"):
        conector().buscar_produtos(None)


def test_lista_que_nao_e_lista(pedidos):
    pedidos["resposta"] = '{"produtos": []}'
    with pytest.raises(ErroErp, match="era pra vir uma lista"):
        conector().buscar_produtos(None)
