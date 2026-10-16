from datetime import date

from models.database import db
from models.lote_model import Lote
from models.produto_model import Produto
from services.utils import usuario_logado


# ordem de saida dos lotes (regra unica do sistema; a Etapa 9 mostra essa ordem pro usuario):
#   1. vence primeiro, sai primeiro
#   2. lote sem validade sai por ultimo
#   3. empate: o que entrou antes sai antes
def ordenar_lotes_para_saida(lotes):
    return sorted(lotes, key=lambda l: (
        l.data_validade is None,
        l.data_validade or date.max,
        l.data_entrada or date.min,
        l.id_lote or 0,
    ))


# toda mudanca de estoque passa por aqui. o estoque e a validade do produto sao derivados dos lotes:
#   quantidade_estoque = soma dos saldos dos lotes
#   data_validade      = menor validade entre os lotes que ainda tem saldo
# os metodos NAO fazem commit: quem chama grava tudo junto (venda + baixa + produto num commit so)
class EstoqueLoteService:

    def lotes_com_saldo(self, produto):
        self.garantir_lote_inicial(produto)
        return [l for l in produto.lotes if l.quantidade_atual > 0]

    # produto com estoque mas sem lote nenhum (dado antigo, de antes dos lotes): vira um "estoque inicial"
    def garantir_lote_inicial(self, produto):
        estoque = produto.quantidade_estoque or 0
        if estoque > 0 and not produto.lotes:
            # o add e obrigatorio: ligar o lote ao produto nao poe o lote na sessao (SQLAlchemy 2)
            db.session.add(Lote(
                produto=produto,
                data_entrada=date.today(),
                data_validade=produto.data_validade,
                quantidade_inicial=estoque,
                quantidade_atual=estoque,
                custo_unitario=produto.preco_custo,
                origem="inicial",
            ))

    def entrada(self, produto, quantidade, data_validade=None, codigo_lote=None, custo_unitario=None,
                data_entrada=None, origem="entrada"):
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
        db.session.add(lote)
        self.sincronizar_produto(produto)
        return lote

    # tira a quantidade dos lotes na ordem de saida. devolve [(lote, quanto saiu dele)]
    def baixar(self, produto, quantidade):
        lotes = ordenar_lotes_para_saida(self.lotes_com_saldo(produto))
        if quantidade > sum(l.quantidade_atual for l in lotes):
            raise ValueError("estoque insuficiente")
        consumidos = []
        falta = quantidade
        for lote in lotes:
            if falta == 0:
                break
            sai = min(falta, lote.quantidade_atual)
            lote.quantidade_atual -= sai
            falta -= sai
            consumidos.append((lote, sai))
        self.sincronizar_produto(produto)
        return consumidos

    # deixa o estoque do produto em `nova_quantidade`: sobrando, cria um lote de ajuste; faltando, baixa
    def ajustar_para(self, produto, nova_quantidade, data_validade=None, origem="ajuste"):
        atual = sum(l.quantidade_atual for l in self.lotes_com_saldo(produto))
        diferenca = (nova_quantidade or 0) - atual
        if diferenca > 0:
            self.entrada(produto, diferenca, data_validade=data_validade, origem=origem)
        elif diferenca < 0:
            self.baixar(produto, -diferenca)
        else:
            self.sincronizar_produto(produto)

    def sincronizar_produto(self, produto):
        com_saldo = [l for l in produto.lotes if l.quantidade_atual > 0]
        produto.quantidade_estoque = sum(l.quantidade_atual for l in com_saldo)
        validades = [l.data_validade for l in com_saldo if l.data_validade]
        produto.data_validade = min(validades) if validades else None


# roda quando a API sobe: produto antigo com estoque e sem lote ganha o "estoque inicial".
# pode rodar quantas vezes for: quem ja tem lote nao e mexido. devolve quantos lotes criou
def criar_lotes_iniciais():
    servico = EstoqueLoteService()
    criados = 0
    for produto in Produto.query.filter(Produto.quantidade_estoque > 0).all():
        if not produto.lotes:
            servico.garantir_lote_inicial(produto)
            criados += 1
    if criados:
        db.session.commit()
    return criados
