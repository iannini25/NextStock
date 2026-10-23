from datetime import date
from unittest.mock import Mock

import pytest

from services.corrigir_lote_service import CorrigirLoteService
from services.listar_lotes_vencendo_service import ListarLotesVencendoService
from services.registrar_entrada_lote_service import RegistrarEntradaLoteService


def test_lote_inicial_legado_e_criado_uma_vez_so():
    from models.lote_model import Lote
    from models.produto_model import Produto
    from services.criar_lotes_iniciais_service import CriarLotesIniciaisService

    Produto(nome="Legado", preco_venda=5, quantidade_estoque=12).salvar()
    assert CriarLotesIniciaisService().executar() == 1
    assert CriarLotesIniciaisService().executar() == 0
    assert Lote.query.one().quantidade_atual == 12


def test_entrada_coordena_persistencia_e_estoque_com_data_fixa():
    model, estoque = Mock(), Mock()
    resposta = RegistrarEntradaLoteService(model, estoque, lambda: date(2026, 10, 21)).executar(
        {"id_produto": 7, "quantidade": "3", "codigo_lote": " L1 ", "custo_unitario": 2.5})
    estoque.entrada.assert_called_once_with(model.buscar_por_id.return_value, 3, data_validade=None,
        codigo_lote="L1", custo_unitario=2.5, data_entrada=date(2026, 10, 21))
    estoque.entrada.return_value.salvar.assert_called_once_with()
    assert resposta["lote"] == estoque.entrada.return_value.virar_dict.return_value


def test_correcao_sincroniza_validade_antes_de_confirmar():
    model, estoque = Mock(), Mock()
    CorrigirLoteService(model, estoque).executar(1, {"codigo_lote": " L2 ", "data_validade": "2026-11-01"})
    model.buscar_por_id.return_value.atualizar.assert_called_once_with("L2", date(2026, 11, 1), confirmar=False)
    estoque.sincronizar_produto.assert_called_once_with(model.buscar_por_id.return_value.produto)
    model.buscar_por_id.return_value.salvar.assert_called_once_with()


@pytest.mark.parametrize("dias", ["abc", 1.5, True, -1, 366])
def test_validade_invalida_nao_consulta_banco(dias):
    repo = Mock()
    with pytest.raises(ValueError):
        ListarLotesVencendoService(repo).executar(dias)
    repo.listar_vencendo.assert_not_called()


@pytest.mark.parametrize("dias, esperado", [(None, 7), ("", 7), (0, 0), (365, 365)])
def test_validade_padrao_e_limites(dias, esperado):
    repo = Mock()
    repo.listar_vencendo.return_value = []
    assert ListarLotesVencendoService(repo).executar(dias) == []
    repo.listar_vencendo.assert_called_once_with(esperado)


@pytest.mark.parametrize("quantidade", [True, 1.5, 1.0])
def test_entrada_invalida_nao_altera_saldo(client, quantidade):
    from models.lote_model import Lote
    from tests.fabricas import criar_produto

    produto = criar_produto("Leite", quantidade_estoque=3)
    assert client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade}).status_code == 400
    assert produto.quantidade_estoque == 3
    assert Lote.query.one().quantidade_atual == 3


def test_falha_no_commit_da_correcao_restaura_lote_e_validade_produto(client, monkeypatch):
    from models.database import db
    from models.lote_model import Lote
    from tests.fabricas import criar_produto, dia

    produto = criar_produto("Leite", quantidade_estoque=3, data_validade=dia(5))
    lote = Lote.query.one()
    validade = produto.data_validade

    def falhar():
        db.session.flush()
        raise RuntimeError("falha simulada")

    monkeypatch.setattr(db.session, "commit", falhar)
    assert client.put(f"/lotes/{lote.id_lote}", json={"codigo_lote": "Novo", "data_validade": dia(20).isoformat()}).status_code == 500
    db.session.expire_all()
    assert produto.data_validade == lote.data_validade == validade
    assert lote.codigo_lote is None
