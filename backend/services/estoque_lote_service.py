from datetime import date, datetime

from models.database import db
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.produto_model import Produto
from services.planejar_saida_service import PlanejarSaidaService
from services.priorizar_lotes_service import PriorizarLotesService
from services.utils import usuario_logado


# ordem de saida dos lotes (PVPS: primeiro que vence, primeiro que sai). regra unica do sistema:
#   1. vence primeiro, sai primeiro
#   2. lote sem validade sai depois dos que tem validade
#   3. empate: o que entrou antes sai antes (PEPS)
#   4. lote JA VENCIDO vai pro fim da fila: vencido e pra retirar/descartar, nao pra vender.
#      so sai numa venda se nao sobrar mais nada (e a previa da venda avisa)
def ordenar_lotes_para_saida(lotes):
    return PriorizarLotesService().executar(lotes)


# de quais lotes (e quanto de cada) sairia `quantidade`, sem mexer em nada.
# devolve ([(lote, quanto sai)], quanto falta). a baixa de verdade e a previa da venda usam esta mesma conta
def planejar_saida(lotes, quantidade):
    return PlanejarSaidaService().executar(lotes, quantidade)


# toda mudanca de estoque passa por aqui. o estoque e a validade do produto sao derivados dos lotes:
#   quantidade_estoque = soma dos saldos dos lotes
#   data_validade      = menor validade entre os lotes que ainda tem saldo
# e cada mudanca vira um registro em movimentacao_estoque (o historico).
# os metodos NAO fazem commit: quem chama grava tudo junto (venda + baixa + historico num commit so)
class EstoqueLoteService:

    # origem_movimento: de onde a mudanca veio (manual, planilha, erp, sistema) - vai pro historico
    def __init__(self, origem_movimento="manual", planejador=None):
        self.origem_movimento = origem_movimento
        self.planejador = planejador if planejador is not None else PlanejarSaidaService()

    def lotes_com_saldo(self, produto):
        self.garantir_lote_inicial(produto)
        return [l for l in produto.lotes if l.quantidade_atual > 0]

    # produto com estoque mas sem lote nenhum (dado antigo, de antes dos lotes): vira um "estoque inicial"
    def garantir_lote_inicial(self, produto):
        estoque = produto.quantidade_estoque or 0
        if estoque > 0 and not produto.lotes:
            # o add e obrigatorio: ligar o lote ao produto nao poe o lote na sessao (SQLAlchemy 2)
            lote = Lote(
                produto=produto,
                data_entrada=date.today(),
                data_validade=produto.data_validade,
                quantidade_inicial=estoque,
                quantidade_atual=estoque,
                custo_unitario=produto.preco_custo,
                origem="inicial",
            )
            lote.salvar(confirmar=False)
            self.registrar(produto, lote, "saldo_inicial", estoque, origem="sistema")

    # origem = de onde o LOTE veio (entrada, inicial, ajuste, importacao, erp)
    # tipo   = como entra no historico; por padrao "saldo_inicial" pro cadastro e "entrada" pro resto
    def entrada(self, produto, quantidade, data_validade=None, codigo_lote=None, custo_unitario=None,
                data_entrada=None, origem="entrada", tipo=None, observacao=None):
        if not quantidade or quantidade <= 0:
            raise ValueError("quantidade tem que ser maior que zero")
        self.garantir_lote_inicial(produto)
        usuario = usuario_logado()
        lote = Lote(
            produto=produto,
            codigo_lote=codigo_lote,
            data_entrada=data_entrada or date.today(),
            data_validade=data_validade,
            quantidade_inicial=quantidade,
            quantidade_atual=quantidade,
            custo_unitario=custo_unitario if custo_unitario is not None else produto.preco_custo,
            origem=origem,
            id_usuario=usuario.id_usuario if usuario else None,
        )
        lote.salvar(confirmar=False)
        self.sincronizar_produto(produto)
        tipo = tipo or ("saldo_inicial" if origem == "inicial" else "entrada")
        self.registrar(produto, lote, tipo, quantidade, observacao=observacao)
        return lote

    # tira a quantidade dos lotes na ordem de saida. devolve [(lote, quanto saiu dele)].
    # cada lote que entrou na baixa vira um registro no historico (uma venda pode atravessar 2 lotes)
    def baixar(self, produto, quantidade, tipo="venda", id_venda=None, observacao=None):
        plano, falta = self.planejador.executar(self.lotes_com_saldo(produto), quantidade)
        if falta > 0:
            raise ValueError("estoque insuficiente")
        for lote, sai in plano:
            lote.quantidade_atual -= sai
            self.registrar(produto, lote, tipo, sai, id_venda=id_venda, observacao=observacao)
        self.sincronizar_produto(produto)
        return plano

    # tira de UM lote escolhido (perda/descarte: sai do lote que estragou, nao pela fila de saida).
    # devolve o registro do historico
    def baixar_do_lote(self, lote, quantidade, tipo, observacao=None):
        if not quantidade or quantidade <= 0:
            raise ValueError("quantidade tem que ser maior que zero")
        if quantidade > lote.quantidade_atual:
            raise ValueError(f"o lote só tem {lote.quantidade_atual} em estoque")
        lote.quantidade_atual -= quantidade
        movimentacao = self.registrar(lote.produto, lote, tipo, quantidade, observacao=observacao)
        self.sincronizar_produto(lote.produto)
        return movimentacao

    # deixa o estoque do produto em `nova_quantidade`: sobrando, cria um lote de ajuste; faltando, baixa
    def ajustar_para(self, produto, nova_quantidade, data_validade=None, origem="ajuste"):
        atual = sum(l.quantidade_atual for l in self.lotes_com_saldo(produto))
        diferenca = (nova_quantidade or 0) - atual
        if diferenca > 0:
            self.entrada(produto, diferenca, data_validade=data_validade, origem=origem, tipo="ajuste_entrada")
        elif diferenca < 0:
            self.baixar(produto, -diferenca, tipo="ajuste_saida")
        else:
            self.sincronizar_produto(produto)

    def sincronizar_produto(self, produto):
        com_saldo = [l for l in produto.lotes if l.quantidade_atual > 0]
        produto.quantidade_estoque = sum(l.quantidade_atual for l in com_saldo)
        validades = [l.data_validade for l in com_saldo if l.data_validade]
        produto.data_validade = min(validades) if validades else None

    # uma linha no historico, com o saldo do produto logo depois dessa mudanca
    def registrar(self, produto, lote, tipo, quantidade, id_venda=None, observacao=None, origem=None):
        usuario = usuario_logado()
        movimentacao = MovimentacaoEstoque(
            produto=produto,
            lote=lote,
            tipo=tipo,
            quantidade=quantidade,
            saldo_produto_apos=sum(l.quantidade_atual for l in produto.lotes),
            custo_unitario=lote.custo_unitario if lote else None,
            id_venda=id_venda,
            id_usuario=usuario.id_usuario if usuario else None,
            origem=origem or self.origem_movimento,
            observacao=observacao,
            data_hora=datetime.now(),
        )
        movimentacao.salvar(confirmar=False)
        return movimentacao
