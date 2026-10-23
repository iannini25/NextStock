from datetime import datetime
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from models.categoria_model import Categoria
from models.database import db
from models.erp_venda_importada_model import ErpVendaImportada
from models.produto_model import Produto
from models.venda_model import Venda
from services.importar_erp_service import ImportarErpService
from services.importar_venda_erp_service import ImportarVendaErpService
from services.sincronizar_erp_service import SincronizarErpService
from tests.fabricas import criar_produto


def test_coordenador_continua_apos_erro_e_conta_repetidas():
    produtos, vendas = Mock(), Mock()
    produtos.executar.side_effect = [ValueError("inválido"), "criado", "atualizado"]
    vendas.executar.side_effect = ["importada", "repetida"]
    resultado = ImportarErpService("sincronizacao", produtos, vendas).importar(
        [{"codigo_barras": "a"}, {}, {}], [{}, {}])
    assert resultado == {"produtos_criados": 1, "produtos_atualizados": 1, "vendas_importadas": 1,
                         "vendas_ja_importadas": 1, "erros": ["produto a: inválido"]}


@pytest.mark.parametrize("produtos,vendas", [({}, []), ([], "x"), (1, [])])
def test_importacao_recusa_colecoes_que_nao_sao_listas(produtos, vendas):
    with pytest.raises(ValueError, match="listas"):
        ImportarErpService().importar(produtos, vendas)


def test_sincronizacao_ocupada_nao_chama_erp_nem_importa():
    agora = datetime(2026, 10, 21, 10)
    repo, conector, importador = Mock(), Mock(), Mock()
    repo.em_andamento.return_value = SimpleNamespace(iniciado_em=agora)
    fabrica = Mock(return_value=(conector, SimpleNamespace(ativo=True)))
    with pytest.raises(ValueError, match="em andamento"):
        SincronizarErpService(repo, fabrica, importador, lambda: agora).executar()
    conector.buscar_produtos.assert_not_called()
    importador.importar.assert_not_called()


def test_falha_ao_salvar_marcador_reverte_venda_e_permite_repetir_sem_duplicar(monkeypatch):
    produto = criar_produto("Leite", codigo_barras="111", quantidade_estoque=10)
    dados = {"id_externo": "V-1", "codigo_barras": "111", "quantidade": 2}
    original = ErpVendaImportada.salvar

    def falhar(self):
        db.session.add(self)
        db.session.flush()
        raise RuntimeError("falha do marcador")

    monkeypatch.setattr(ErpVendaImportada, "salvar", falhar)
    with pytest.raises(RuntimeError, match="marcador"):
        ImportarVendaErpService(True).executar(dados)
    assert Venda.query.count() == ErpVendaImportada.query.count() == 0
    assert produto.quantidade_estoque == 10
    monkeypatch.setattr(ErpVendaImportada, "salvar", original)
    assert ImportarVendaErpService(True).executar(dados) == "importada"
    assert ImportarVendaErpService(True).executar(dados) == "repetida"
    assert Venda.query.count() == ErpVendaImportada.query.count() == 1
    assert produto.quantidade_estoque == 10


def test_produto_invalido_nao_suja_entidades_antes_do_proximo_item():
    produto = criar_produto("Original", codigo_barras="111", quantidade_estoque=5)
    resultado = ImportarErpService("sincronizacao").importar([
        {"codigo_barras": "111", "nome": "Corrompido", "preco_venda": 9,
         "categoria": "Fantasma", "quantidade_estoque": "abc"},
        {"codigo_barras": "222", "nome": "Válido", "preco_venda": 5},
    ], [])
    db.session.expire_all()
    assert produto.nome == "Original"
    assert produto.quantidade_estoque == 5
    assert Categoria.buscar_por_nome("Fantasma") is None
    assert (resultado["produtos_criados"], len(resultado["erros"])) == (1, 1)


@pytest.mark.parametrize("dados", [[1], True, "x"])
def test_importar_json_invalido_devolve_400(client, dados):
    assert client.post("/erp/importar", json=dados).status_code == 400
