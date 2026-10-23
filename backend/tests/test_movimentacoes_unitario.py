from datetime import date
from unittest.mock import Mock

import pytest

from services.listar_movimentacoes_service import ListarMovimentacoesService


def test_filtros_convertidos_e_paginacao_encaminhados_sem_query():
    repo, item = Mock(), Mock()
    repo.listar_com_filtros.return_value = ([item], 9)
    resposta = ListarMovimentacoesService(repo).executar({"id_produto": "3", "id_lote": "4", "tipo": "venda",
        "origem": "erp", "inicio": "2026-10-01", "fim": "2026-10-21", "pagina": "2", "limite": "5"})
    repo.listar_com_filtros.assert_called_once_with(3, 4, "venda", "erp", date(2026, 10, 1), date(2026, 10, 21), 2, 5)
    assert (resposta["total"], resposta["pagina"], resposta["limite"]) == (9, 2, 5)
    assert resposta["itens"] == [item.virar_dict.return_value]


@pytest.mark.parametrize("campo, valor", [("pagina", True), ("limite", 2.5), ("id_produto", False),
                                         ("id_lote", "abc"), ("pagina", 0), ("limite", 201)])
def test_filtro_invalido_nao_chama_repository(campo, valor):
    repo = Mock()
    with pytest.raises(ValueError):
        ListarMovimentacoesService(repo).executar({campo: valor})
    repo.listar_com_filtros.assert_not_called()
