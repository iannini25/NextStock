from io import BytesIO
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from models.database import db
from models.produto_model import Produto
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from services.gerar_modelo_planilha_service import GerarModeloPlanilhaService
from services.importar_planilha_service import ImportarPlanilhaService
from services.importar_produto_planilha_service import ImportarProdutoPlanilhaService
from services.ler_planilha_service import LerPlanilhaService


def test_coordenador_isola_erro_por_linha_e_preserva_numeracao():
    leitor, caso = Mock(), Mock()
    leitor.executar.return_value = ([{'nome': 'A'}, {'nome': ''}, {'nome': 'B'}, {'nome': 'C'}], {'nome'})
    caso.executar.side_effect = ['ok', ValueError('inválido'), 'skip']
    arquivo = SimpleNamespace(filename='categorias.csv', read=lambda: b'nome\nA')
    resultado = ImportarPlanilhaService(leitor, {'categorias': caso}).executar('categorias', arquivo)
    assert resultado == {'importados': 1, 'ignorados': 2, 'erros': ['Linha 4: inválido']}
    assert caso.executar.call_count == 3


def test_modelo_gerado_pode_ser_lido_com_o_mesmo_cabecalho():
    arquivo, nome = GerarModeloPlanilhaService().executar('vendas')
    linhas, cabecalhos = LerPlanilhaService().executar(nome, arquivo.read())
    assert cabecalhos == {'id_produto', 'quantidade', 'data_venda'}
    assert linhas[0]['quantidade'] == '3'


def test_falha_apos_criar_lote_reverte_produto_saldo_e_historico(monkeypatch):
    salvar = Produto.salvar

    def falhar_no_commit(self, confirmar=True):
        if confirmar:
            db.session.flush()
            raise RuntimeError('falha no commit')
        return salvar(self, confirmar=False)

    monkeypatch.setattr(Produto, 'salvar', falhar_no_commit)
    with pytest.raises(RuntimeError, match='falha no commit'):
        ImportarProdutoPlanilhaService().executar({'nome': 'Leite', 'preco_venda': '5', 'quantidade_estoque': '7'})
    assert Produto.query.count() == Lote.query.count() == MovimentacaoEstoque.query.count() == 0
