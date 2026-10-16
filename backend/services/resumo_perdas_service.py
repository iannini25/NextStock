from datetime import datetime, timedelta

from models.perda_model import Perda


# perdas dos ultimos X dias: o total em R$, quanto por motivo e quais produtos mais deram prejuizo
class ResumoPerdasService:

    def executar(self, dias):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 30
        if dias < 1 or dias > 365:
            raise ValueError("dias tem que ser entre 1 e 365")
        desde = datetime.now() - timedelta(days=dias)
        perdas = Perda.query.filter(Perda.data_registro >= desde).all()

        por_motivo = {}
        por_produto = {}
        for p in perdas:
            valor = float(p.valor_total or 0)
            m = por_motivo.setdefault(p.motivo, {"motivo": p.motivo, "nome": Perda.MOTIVOS.get(p.motivo, p.motivo),
                                                 "valor": 0.0, "quantidade": 0, "registros": 0})
            m["valor"] += valor
            m["quantidade"] += p.quantidade
            m["registros"] += 1
            pr = por_produto.setdefault(p.id_produto, {"id_produto": p.id_produto, "produto_nome": p.produto.nome,
                                                       "valor": 0.0, "quantidade": 0})
            pr["valor"] += valor
            pr["quantidade"] += p.quantidade

        def arredondar(itens):
            for i in itens:
                i["valor"] = round(i["valor"], 2)
            return sorted(itens, key=lambda i: i["valor"], reverse=True)

        return {
            "dias": dias,
            "valor_total": round(sum(float(p.valor_total or 0) for p in perdas), 2),
            "quantidade_total": sum(p.quantidade for p in perdas),
            "registros": len(perdas),
            "por_motivo": arredondar(list(por_motivo.values())),
            "por_produto": arredondar(list(por_produto.values())),
        }
