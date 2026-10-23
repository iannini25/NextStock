from models.produto_model import Produto
from services.classificar_curva_abc_service import ClassificarCurvaAbcService
from services.estoque_lote_service import ordenar_lotes_para_saida
from services.prever_demanda_service import PreverDemandaService

HORIZONTE_PREVISAO = 30  # dias de previsao usados pra estimar a venda por dia
VALOR_ALTO = 100.0  # a partir daqui o valor em risco sobe a prioridade
NIVEIS = ["baixa", "media", "alta"]


def subir(prioridade, niveis=1):
    return NIVEIS[min(NIVEIS.index(prioridade) + niveis, len(NIVEIS) - 1)]


# prioridade da falta (Vai faltar): pela classe ABC; produto zerado e sempre alta
def prioridade_da_falta(classe, estoque):
    if estoque <= 0:
        return "alta"
    return {"A": "alta", "B": "media"}.get(classe, "baixa")


# excesso de estoque, de dois jeitos:
#   perecivel: com a venda prevista por dia, simula os lotes saindo na ordem de saida e ve quanto de cada lote
#              nao vai ser vendido antes de vencer (quantidade e valor em risco)
#   cobertura: estoque que demora mais que `dias_cobertura` dias pra vender (ou que nao tem venda prevista)
# prioridade: prazo + valor em risco + classe ABC (classe A sobe um nivel)
class AlertasExcessoService:

    def executar(self, dias_cobertura=30, previsoes=None, classes=None):
        try:
            dias_cobertura = int(dias_cobertura)
        except (TypeError, ValueError):
            dias_cobertura = 30
        if dias_cobertura < 1 or dias_cobertura > 365:
            raise ValueError("dias_cobertura tem que ser entre 1 e 365")
        if previsoes is None:
            previsoes = PreverDemandaService().executar(HORIZONTE_PREVISAO, "auto")
        if classes is None:
            classes = ClassificarCurvaAbcService().classes()
        demanda = {p["id_produto"]: p["previsao_demanda"] / HORIZONTE_PREVISAO for p in previsoes}

        alertas = []
        for produto in Produto.listar_todos():
            por_dia = demanda.get(produto.id_produto, 0)
            classe = classes.get(produto.id_produto, "C")
            alertas += self.excesso_perecivel(produto, por_dia, classe)
            cobertura = self.excesso_de_cobertura(produto, por_dia, classe, dias_cobertura)
            if cobertura:
                alertas.append(cobertura)

        ordem = {"alta": 0, "media": 1, "baixa": 2}
        alertas.sort(key=lambda a: (ordem[a["prioridade"]], -a["valor_em_risco"], a["produto_nome"]))
        return alertas

    def excesso_perecivel(self, produto, por_dia, classe):
        alertas = []
        inicio = 0.0  # dia em que o lote comeca a ser vendido (os anteriores na fila saem antes)
        lotes = [l for l in produto.lotes if l.quantidade_atual > 0 and not self.vencido(l)]
        for lote in ordenar_lotes_para_saida(lotes):
            dias = lote.dias_para_vencer()
            if dias is None:  # sem validade: nao estraga, so leva tempo pra vender
                if por_dia > 0:
                    inicio += lote.quantidade_atual / por_dia
                continue
            tempo_ate_vencer = max(dias + 1 - inicio, 0)  # o dia do vencimento ainda vende
            vende = min(lote.quantidade_atual, por_dia * tempo_ate_vencer)
            sobra = lote.quantidade_atual - int(vende)
            inicio = (inicio + vende / por_dia) if (sobra == 0 and por_dia > 0) else max(inicio, dias + 1)
            if sobra <= 0:
                continue
            custo = lote.custo_unitario if lote.custo_unitario is not None else produto.preco_custo
            valor = round(sobra * float(custo or 0), 2)
            prioridade = "alta" if dias <= 3 else ("media" if dias <= 7 else "baixa")
            if valor >= VALOR_ALTO:
                prioridade = subir(prioridade)
            if classe == "A":
                prioridade = subir(prioridade)
            alertas.append(self.montar(
                produto, "perecivel", prioridade, classe, por_dia,
                quantidade=sobra, valor=valor, lote=lote,
                mensagem=(f"{lote.titulo()}: {sobra} de {lote.quantidade_atual} {produto.unidade or 'UN'} "
                          f"não devem ser vendidos antes de vencer (em {dias} dia(s)) - "
                          f"R$ {valor:.2f} em risco. Faça promoção ou compre menos."),
            ))
        return alertas

    def excesso_de_cobertura(self, produto, por_dia, classe, dias_cobertura):
        estoque = produto.quantidade_estoque or 0
        # no minimo ou abaixo dele o produto esta no Vai faltar: nao pode ser excesso ao mesmo tempo
        if estoque <= 0 or estoque <= (produto.estoque_minimo or 0):
            return None
        if por_dia <= 0:
            dias = None
            sobra = estoque
            mensagem = f"Sem venda prevista: {estoque} {produto.unidade or 'UN'} parados no estoque."
        else:
            dias = int(estoque / por_dia)
            if dias <= dias_cobertura:
                return None
            sobra = estoque - int(por_dia * dias_cobertura)
            mensagem = (f"Estoque de {estoque} {produto.unidade or 'UN'} cobre {dias} dias de venda "
                        f"(o ideal é até {dias_cobertura}): compre menos.")
        valor = round(sobra * float(produto.preco_custo or 0), 2)
        prioridade = "media" if (dias is None or dias > 2 * dias_cobertura) else "baixa"
        if classe == "A":
            prioridade = subir(prioridade)
        alerta = self.montar(produto, "cobertura", prioridade, classe, por_dia,
                             quantidade=sobra, valor=valor, mensagem=mensagem)
        alerta["dias_cobertura"] = dias
        return alerta

    @staticmethod
    def vencido(lote):
        dias = lote.dias_para_vencer()
        return dias is not None and dias < 0

    @staticmethod
    def montar(produto, tipo, prioridade, classe, por_dia, quantidade, valor, mensagem, lote=None):
        return {
            "tipo": tipo,
            "prioridade": prioridade,
            "classe_abc": classe,
            "id_produto": produto.id_produto,
            "produto_nome": produto.nome,
            "unidade": produto.unidade,
            "id_lote": lote.id_lote if lote else None,
            "lote": lote.titulo() if lote else None,
            "data_validade": lote.data_validade.isoformat() if lote and lote.data_validade else None,
            "dias_para_vencer": lote.dias_para_vencer() if lote else None,
            "quantidade_em_risco": quantidade,
            "valor_em_risco": valor,
            "demanda_diaria": round(por_dia, 2),
            "dias_cobertura": None,
            "mensagem": mensagem,
        }
