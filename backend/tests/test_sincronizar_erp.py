from datetime import datetime, timedelta
from types import SimpleNamespace

import pytest

from models.database import db
from models.sincronizacao_erp_model import SincronizacaoErp
from models.produto_model import Produto
from models.venda_model import Venda
from services.erp import fabrica
from services.erp.conector_erp import ConectorErp, ErroErp
from services.registrar_venda_service import RegistrarVendaService
from tests.fabricas import criar_produto, dia

ARROZ = {"codigo_barras": "789001", "nome": "Arroz 5kg", "preco_venda": 27.9, "quantidade_estoque": 40, "categoria": "Mercearia"}


def venda(id_externo, quantidade=3, codigo="789001", dias_atras=1):
    return {"id_externo": id_externo, "codigo_barras": codigo, "quantidade": quantidade,
            "data_venda": dia(-dias_atras).isoformat()}


@pytest.fixture
def erp(monkeypatch, client):
    # ERP falso no lugar do conector generico; a configuracao (URL + chave criptografada) e a de verdade
    estado = SimpleNamespace(produtos=[], vendas=[], falha=None, desdes=[], chave=None, url=None, explodir=False)

    class ErpFalso(ConectorErp):
        def testar_conexao(self):
            estado.chave, estado.url = self.chave, self.url_base
            if estado.falha:
                raise ErroErp(estado.falha)
            return {"status": "ok"}

        def buscar_produtos(self, desde):
            estado.desdes.append(desde)
            if estado.falha:
                raise ErroErp(estado.falha)
            return list(estado.produtos)

        def buscar_vendas(self, desde):
            if estado.explodir:
                raise RuntimeError("bug")
            return list(estado.vendas)

    monkeypatch.setitem(fabrica.CONECTORES, "generico", ErpFalso)
    r = client.put("/erp/configuracao", json={"url_base": "http://erp.teste", "chave_api": "chave-erp-123"})
    assert r.status_code == 200
    return estado


def sincronizar(client):
    return client.post("/erp/sincronizar")


# ---------- teste de conexao ----------

def test_testar_conexao_usa_a_chave_salva(client, erp):
    r = client.post("/erp/testar-conexao")
    assert r.status_code == 200
    assert r.get_json() == {"ok": True, "mensagem": "Conexão com o ERP funcionando", "detalhes": {"status": "ok"}}
    assert erp.chave == "chave-erp-123"  # descriptografou a chave salva
    assert erp.url == "http://erp.teste"


def test_testar_conexao_com_erp_falhando(client, erp):
    erp.falha = "o ERP recusou a chave da API (HTTP 401): confira a chave cadastrada"
    r = client.post("/erp/testar-conexao")
    assert r.status_code == 502
    assert r.get_json() == {"erro": erp.falha}


def test_sem_configuracao(client):
    for rota in ("/erp/testar-conexao", "/erp/sincronizar"):
        r = client.post(rota)
        assert r.status_code == 400
        assert r.get_json() == {"erro": "configure a integração com o ERP primeiro (URL e chave)"}


def test_sem_chave(client, erp):
    client.delete("/erp/configuracao/chave")
    r = client.post("/erp/testar-conexao")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "cadastre a chave da API do ERP primeiro"}


# ---------- sincronizacao ----------

def test_sincroniza_produtos_e_vendas_sem_baixa_dupla(client, erp):
    erp.produtos = [ARROZ]
    erp.vendas = [venda("V1", 3), venda("V2", 2, dias_atras=2)]
    r = sincronizar(client)
    assert r.status_code == 200
    corpo = r.get_json()
    assert corpo["status"] == "sucesso"
    assert (corpo["produtos_criados"], corpo["produtos_atualizados"], corpo["vendas_importadas"]) == (1, 0, 2)
    assert corpo["erros"] == []
    assert corpo["usuario"] == "Admin"

    arroz = Produto.buscar_por_codigo("789001")
    assert arroz.quantidade_estoque == 40  # o estoque e o do ERP; as vendas nao baixam de novo
    assert arroz.categoria.nome == "Mercearia"
    assert Venda.query.count() == 2


def test_segunda_sincronizacao_nao_duplica_vendas(client, erp):
    erp.produtos = [ARROZ]
    erp.vendas = [venda("V1")]
    sincronizar(client)
    segunda = sincronizar(client).get_json()
    assert segunda["vendas_importadas"] == 0
    assert segunda["vendas_ja_importadas"] == 1
    assert segunda["produtos_atualizados"] == 1
    assert Venda.query.count() == 1


def test_busca_so_o_que_mudou_desde_a_ultima_que_deu_certo(client, erp):
    sincronizar(client)
    sincronizar(client)
    primeira = SincronizacaoErp.query.order_by(SincronizacaoErp.id_sincronizacao).first()
    assert erp.desdes[0] is None  # a primeira traz tudo
    assert erp.desdes[1] == primeira.iniciado_em - timedelta(minutes=10)  # com margem


def test_depois_de_sincronizacao_com_erro_busca_tudo_de_novo(client, erp):
    erp.produtos = [ARROZ]
    erp.vendas = [venda("V1", codigo="nao-existe")]
    assert sincronizar(client).get_json()["status"] == "parcial"
    sincronizar(client)
    assert erp.desdes == [None, None]


def test_preserva_o_que_o_erp_nao_manda(client, erp):
    criar_produto("Arroz antigo", codigo_barras="789001", estoque_minimo=7, data_validade=dia(30),
                  preco_custo=10, quantidade_estoque=1)
    erp.produtos = [{"codigo_barras": "789001", "nome": "Arroz 5kg", "preco_venda": 29.9, "quantidade_estoque": 55}]
    assert sincronizar(client).get_json()["produtos_atualizados"] == 1

    arroz = Produto.buscar_por_codigo("789001")
    assert arroz.nome == "Arroz 5kg"
    assert float(arroz.preco_venda) == 29.9
    assert arroz.quantidade_estoque == 55
    assert arroz.estoque_minimo == 7  # definido no NextStock, o ERP nao mandou
    assert arroz.data_validade == dia(30)
    assert float(arroz.preco_custo) == 10


def test_venda_do_erp_entra_mesmo_sem_estoque_no_nextstock(client, erp):
    erp.produtos = [{**ARROZ, "quantidade_estoque": 0}]
    erp.vendas = [venda("V1", quantidade=5)]
    assert sincronizar(client).get_json()["vendas_importadas"] == 1


def test_erros_por_item_deixam_a_sincronizacao_parcial(client, erp):
    erp.produtos = [ARROZ, {"codigo_barras": "789002"}]
    erp.vendas = [venda("V1"), {"codigo_barras": "789001", "quantidade": 1}, venda("V3", codigo="nao-existe")]
    corpo = sincronizar(client).get_json()
    assert corpo["status"] == "parcial"
    assert corpo["produtos_criados"] == 1
    assert corpo["vendas_importadas"] == 1
    assert corpo["erros"] == [
        "produto 789002: codigo_barras e nome são obrigatórios",
        "venda None: venda sem id_externo",
        "venda V3: produto não encontrado",
    ]


def test_erp_fora_do_ar_fica_no_historico(client, erp):
    erp.falha = "não foi possível conectar ao ERP em http://erp.teste (ConnectionRefusedError). Ele está no ar?"
    r = sincronizar(client)
    assert r.status_code == 502
    assert r.get_json() == {"erro": erp.falha}

    historico = client.get("/erp/sincronizacoes").get_json()
    assert historico[0]["status"] == "erro"
    assert historico[0]["erros"] == [erp.falha]
    assert historico[0]["finalizado_em"]
    assert Produto.query.count() == 0


def test_erro_inesperado_tambem_fica_no_historico(client, erp):
    erp.explodir = True
    assert sincronizar(client).status_code == 500
    s = SincronizacaoErp.query.one()
    assert s.status == "erro"
    assert s.lista_erros() == ["erro inesperado ao gravar os dados: RuntimeError"]


def test_integracao_desligada_nao_sincroniza(client, erp):
    client.put("/erp/configuracao", json={"url_base": "http://erp.teste", "ativo": False})
    r = sincronizar(client)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "a integração com o ERP está desligada (ligue em Integração ativa)"}
    # testar a conexao continua permitido
    assert client.post("/erp/testar-conexao").status_code == 200


def test_nao_roda_duas_ao_mesmo_tempo(client, erp):
    db.session.add(SincronizacaoErp(iniciado_em=datetime.now(), status="em_andamento"))
    db.session.commit()
    r = sincronizar(client)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já tem uma sincronização em andamento, espere ela terminar"}


def test_sincronizacao_travada_ha_muito_tempo_nao_bloqueia(client, erp):
    db.session.add(SincronizacaoErp(iniciado_em=datetime.now() - timedelta(hours=1), status="em_andamento"))
    db.session.commit()
    assert sincronizar(client).status_code == 200


def test_historico_mais_recente_primeiro(client, erp):
    sincronizar(client)
    erp.falha = "fora do ar"
    sincronizar(client)
    historico = client.get("/erp/sincronizacoes").get_json()
    assert [h["status"] for h in historico] == ["erro", "sucesso"]


def test_previsao_usa_as_vendas_que_vieram_do_erp(client, erp):
    erp.produtos = [ARROZ]
    erp.vendas = [venda(f"V{d}", 10, dias_atras=d) for d in range(1, 29)]
    sincronizar(client)
    previsoes = {p["produto_nome"]: p for p in client.get("/previsao").get_json()["previsoes"]}
    assert previsoes["Arroz 5kg"]["previsao_demanda"] == 70


def test_registrar_venda_sem_baixar_estoque(banco):
    p = criar_produto("Leite", quantidade_estoque=2)
    RegistrarVendaService().executar({"id_produto": p.id_produto, "quantidade": 5}, baixar_estoque=False)
    assert Produto.buscar_por_id(p.id_produto).quantidade_estoque == 2
    with pytest.raises(ValueError, match="estoque insuficiente"):  # o padrao continua igual
        RegistrarVendaService().executar({"id_produto": p.id_produto, "quantidade": 5})
