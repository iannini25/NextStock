from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository

# limites da curva ABC (em % do total acumulado)
LIMITE_A = 80
LIMITE_B = 95
CRITERIOS = ("faturamento", "quantidade")


# curva ABC: ordena os produtos do que mais vendeu pro que menos vendeu e soma o percentual de cada um.
#   A = os que fazem os primeiros 80% do total (poucos produtos, a maior parte do dinheiro)
#   B = dos 80% aos 95%
#   C = o resto (muitos produtos, pouco peso). produto sem venda no periodo e sempre C.
# a classe vem do acumulado ANTES do produto: assim o primeiro colocado e sempre A,
# mesmo que sozinho passe dos 80%.
# limitacao herdada dos outros relatorios: o faturamento usa o preco de venda atual (a venda nao guarda o preco)
class ClassificarCurvaAbcService:

    def __init__(self):
        self.repo = VendaRepository()

    def executar(self, dias=30, criterio="faturamento"):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 30
        if dias < 1 or dias > 365:
            raise ValueError("dias tem que ser entre 1 e 365")
        criterio = str(criterio or "faturamento").strip().lower()
        if criterio not in CRITERIOS:
            raise ValueError("criterio tem que ser faturamento ou quantidade")

        hoje = date.today()
        vendido = {}
        for venda in self.repo.listar_por_periodo(hoje - timedelta(days=dias), hoje):
            vendido[venda.id_produto] = vendido.get(venda.id_produto, 0) + venda.quantidade

        itens = []
        for produto in Produto.listar_todos():
            quantidade = vendido.get(produto.id_produto, 0)
            faturamento = quantidade * float(produto.preco_venda or 0)
            itens.append({
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "categoria_nome": produto.categoria.nome if produto.categoria else None,
                "quantidade_vendida": quantidade,
                "faturamento": round(faturamento, 2),
                "valor": faturamento if criterio == "faturamento" else quantidade,
            })
        itens.sort(key=lambda i: (-i["valor"], i["produto_nome"]))

        total = sum(i["valor"] for i in itens)
        acumulado = 0.0
        for posicao, item in enumerate(itens, start=1):
            percentual = item["valor"] / total * 100 if total else 0
            if item["valor"] <= 0:
                classe = "C"
            elif acumulado < LIMITE_A:
                classe = "A"
            elif acumulado < LIMITE_B:
                classe = "B"
            else:
                classe = "C"
            acumulado += percentual
            item.update({
                "posicao": posicao,
                "valor": round(item["valor"], 2),
                "percentual": round(percentual, 2),
                "percentual_acumulado": round(acumulado, 2),
                "classe": classe,
            })

        resumo = {}
        for classe in ("A", "B", "C"):
            da_classe = [i for i in itens if i["classe"] == classe]
            valor = sum(i["valor"] for i in da_classe)
            resumo[classe] = {
                "produtos": len(da_classe),
                "valor": round(valor, 2),
                "percentual_valor": round(valor / total * 100, 2) if total else 0,
            }

        return {
            "dias": dias,
            "criterio": criterio,
            "total": round(total, 2),
            "limites": {"A": LIMITE_A, "B": LIMITE_B},
            "resumo": resumo,
            "itens": itens,
        }

    # so a classe de cada produto ({id_produto: "A"}), pra quem precisa usar a curva (ex.: prioridade dos alertas)
    def classes(self, dias=90, criterio="faturamento"):
        return {i["id_produto"]: i["classe"] for i in self.executar(dias, criterio)["itens"]}
