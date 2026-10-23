from datetime import date, timedelta
from itertools import permutations
from types import SimpleNamespace
from unittest.mock import Mock, call

import pytest

from models.lote_model import Lote
from services.gerar_recomendacoes_service import GerarRecomendacoesService
from services.listar_lotes_produto_service import ListarLotesProdutoService
from services.ordem_saida_service import OrdemSaidaService
from services.planejar_saida_service import PlanejarSaidaService
from services.previa_venda_service import PreviaVendaService
from services.priorizar_lotes_service import PriorizarLotesService
from services.registrar_venda_service import RegistrarVendaService


HOJE = date(2026, 10, 17)


def lote(id, dias, quantidade=3, entrada=-5):
    return Lote(id_lote=id, data_validade=None if dias is None else HOJE + timedelta(days=dias),
                data_entrada=None if entrada is None else HOJE + timedelta(days=entrada),
                quantidade_atual=quantidade, quantidade_inicial=quantidade, origem="entrada")


def test_ordem_com_data_fixa_respeita_validade_hoje_peps_id_sem_validade_e_vencidos():
    lotes = [lote(7, -2), lote(6, None), lote(5, 5), lote(4, 0, entrada=-1),
             lote(3, 0, entrada=-5), lote(2, 0, entrada=-5), lote(1, 0, entrada=None)]
    copia = list(lotes)
    resultado = PriorizarLotesService(lambda: HOJE).executar(lotes)
    assert [l.id_lote for l in resultado] == [1, 2, 3, 4, 5, 6, 7]
    assert lotes == copia  # a ordem de entrada não é alterada


def test_empates_produzem_mesma_ordem_independente_da_ordem_da_consulta():
    lotes = [lote(3, 2), lote(1, 2), lote(2, 2)]
    prioridade = PriorizarLotesService(lambda: HOJE)
    for consulta in permutations(lotes):
        assert [l.id_lote for l in prioridade.executar(consulta)] == [1, 2, 3]


@pytest.mark.parametrize("quantidade", [1, 2, 3, 6, 9, 11, 12])
def test_plano_distribui_apenas_saldo_sem_mutar_os_lotes(quantidade):
    lotes = [lote(4, -1, 2), lote(3, None, 3), lote(2, 8, 4), lote(1, 0, 2), lote(5, 1, 0)]
    saldos = [l.quantidade_atual for l in lotes]
    plano, falta = PlanejarSaidaService(PriorizarLotesService(lambda: HOJE)).executar(lotes, quantidade)
    assert sum(q for _, q in plano) + falta == quantidade
    assert falta == max(quantidade - 11, 0)
    assert [l.id_lote for l, _ in plano] == [1, 2, 3, 4][:len(plano)]
    assert all(0 < q <= l.quantidade_atual for l, q in plano)
    assert [l.quantidade_atual for l in lotes] == saldos


@pytest.mark.parametrize("quantidade", [None, "", 0, -1, True, False, 1.5, 1.0, "abc", "1.5"])
def test_plano_recusa_quantidade_invalida_antes_de_ordenar(quantidade):
    prioridade = Mock()
    with pytest.raises(ValueError):
        PlanejarSaidaService(prioridade).executar([], quantidade)
    prioridade.executar.assert_not_called()


def test_previa_usa_planejador_substituivel_e_formato_da_model_com_relogio_fixo():
    model, planejador = Mock(), Mock()
    lotes = [lote(1, 2), lote(2, -1)]
    produto = SimpleNamespace(id_produto=8, lotes=lotes)
    model.buscar_por_id.return_value = produto
    planejador.executar.return_value = ([(lotes[0], 3), (lotes[1], 1)], 0)
    resultado = PreviaVendaService(model, planejador, lambda: HOJE).executar(8, "4")
    planejador.executar.assert_called_once_with(lotes, 4, hoje=HOJE)
    assert resultado["suficiente"] is True
    assert resultado["lotes"] == [lotes[0].saida(3, HOJE), lotes[1].saida(1, HOJE)]
    assert resultado["aviso"].startswith("parte da venda sairia de lote vencido")


@pytest.mark.parametrize("dias", [-1, 0, None])
def test_previa_legada_simula_lote_sem_anexar_a_model_produto(dias):
    model = Mock()
    produto = SimpleNamespace(id_produto=8, lotes=[], quantidade_estoque=3,
                              data_validade=None if dias is None else HOJE + timedelta(days=dias))
    model.buscar_por_id.return_value = produto
    resultado = PreviaVendaService(model, hoje=lambda: HOJE).executar(8, 5)
    assert produto.lotes == []
    assert produto.quantidade_estoque == 3
    assert (resultado["suficiente"], resultado["falta"]) == (False, 2)
    assert resultado["lotes"][0]["dias_para_vencer"] == dias
    assert resultado["lotes"][0]["id_lote"] is None


@pytest.mark.parametrize("resultado", [None, {"produto": {"nome": "Leite"}, "lotes": []}])
def test_ordem_saida_reutiliza_listagem_sem_repetir_criacao_de_lote(resultado):
    listagem = Mock()
    listagem.executar.return_value = resultado
    assert OrdemSaidaService(listagem).executar(7) is resultado
    listagem.executar.assert_called_once_with(7)


def test_selo_so_no_primeiro_nao_vencido_e_esgotados_sem_posicao():
    lotes = [lote(1, -1), lote(2, 0), lote(3, None), lote(4, 1, 0)]
    produto = Mock(lotes=lotes, quantidade_estoque=9)
    produto_model = Mock()
    produto_model.buscar_por_id.return_value = produto
    resultado = ListarLotesProdutoService(produto_model, hoje=lambda: HOJE).executar(8, todos=True)
    assert [(l["id_lote"], l["posicao_saida"], l["vender_primeiro"]) for l in resultado["lotes"]] == [
        (2, 1, True), (3, 2, False), (1, 3, False), (4, None, False)]


@pytest.mark.parametrize("baixar", [True, False])
def test_registro_preserva_preparacao_id_confirmacao_e_opcao_erp(baixar):
    model, venda_model, estoque = Mock(), Mock(), Mock()
    model.buscar_por_id.return_value = SimpleNamespace(id_produto=7)
    venda = venda_model.return_value
    venda.id_venda = 9
    venda.virar_dict.return_value = {"id_venda": 9}
    consumido = lote(1, 2)
    estoque.baixar.return_value = [(consumido, 2)]
    resposta = RegistrarVendaService(model, venda_model, estoque, lambda: HOJE).executar(
        {"id_produto": 7, "quantidade": 2, "data_venda": "2026-10-01"}, baixar_estoque=baixar)
    venda_model.assert_called_once_with(id_produto=7, quantidade=2, data_venda=date(2026, 10, 1))
    assert venda.salvar.call_args_list == [call(confirmar=False), call()]
    if baixar:
        estoque.baixar.assert_called_once_with(model.buscar_por_id.return_value, 2, id_venda=9)
        assert resposta["lotes_consumidos"] == [consumido.saida(2, HOJE)]
    else:
        estoque.baixar.assert_not_called()
        assert resposta["lotes_consumidos"] == []


def test_recomendacoes_por_lote_respeitam_mesma_data_e_ignoram_esgotados():
    produto = SimpleNamespace(id_produto=7, nome="Leite", quantidade_estoque=9, estoque_minimo=0,
                              lotes=[lote(1, -1), lote(2, 2), lote(3, 30), lote(4, -1, 0)])
    repo, previsao, model = Mock(), Mock(), Mock()
    repo.total_vendido.return_value = 30
    previsao.executar.return_value = []
    model.listar_todos.return_value = [produto]
    recs = GerarRecomendacoesService(repo, previsao, model, hoje=lambda: HOJE).executar()
    assert [(r["tipo"], r["id_lote"]) for r in recs] == [("promocao", 2), ("retirar", 1)]
    assert recs[0]["mensagem"].endswith("(deixe o lote mais novo pra depois)")
    repo.total_vendido.assert_called_once_with(7, HOJE - timedelta(days=30), HOJE)
