from datetime import datetime, timedelta

from models.movimentacao_estoque_model import MovimentacaoEstoque
from services.utils import virar_data


def _inteiro_ou_none(v, campo):
    if v in (None, ""):
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        raise ValueError(campo + " tem que ser número")


class ListarMovimentacoesService:

    LIMITE_PADRAO = 50
    LIMITE_MAXIMO = 200

    # filtros (todos opcionais): id_produto, id_lote, tipo, origem, inicio e fim (aaaa-mm-dd, inclusive),
    # pagina (1, 2, ...) e limite. o mais recente primeiro
    def executar(self, filtros):
        id_produto = _inteiro_ou_none(filtros.get("id_produto"), "id_produto")
        id_lote = _inteiro_ou_none(filtros.get("id_lote"), "id_lote")
        tipo = (filtros.get("tipo") or "").strip() or None
        if tipo and tipo not in MovimentacaoEstoque.TIPOS:
            raise ValueError("tipo inválido. use: " + ", ".join(MovimentacaoEstoque.TIPOS))
        origem = (filtros.get("origem") or "").strip() or None
        if origem and origem not in MovimentacaoEstoque.ORIGENS:
            raise ValueError("origem inválida. use: " + ", ".join(MovimentacaoEstoque.ORIGENS))
        inicio = virar_data(filtros.get("inicio"))
        fim = virar_data(filtros.get("fim"))
        if inicio and fim and inicio > fim:
            raise ValueError("a data de início tem que ser antes da data de fim")
        pagina = _inteiro_ou_none(filtros.get("pagina"), "pagina")
        limite = _inteiro_ou_none(filtros.get("limite"), "limite")
        pagina = 1 if pagina is None else pagina  # sem "or": pagina 0 tem que dar erro, nao virar 1
        limite = self.LIMITE_PADRAO if limite is None else limite
        if pagina < 1:
            raise ValueError("pagina tem que ser 1 ou mais")
        if limite < 1 or limite > self.LIMITE_MAXIMO:
            raise ValueError(f"limite tem que ser entre 1 e {self.LIMITE_MAXIMO}")

        q = MovimentacaoEstoque.query
        if id_produto:
            q = q.filter(MovimentacaoEstoque.id_produto == id_produto)
        if id_lote:
            q = q.filter(MovimentacaoEstoque.id_lote == id_lote)
        if tipo:
            q = q.filter(MovimentacaoEstoque.tipo == tipo)
        if origem:
            q = q.filter(MovimentacaoEstoque.origem == origem)
        if inicio:
            q = q.filter(MovimentacaoEstoque.data_hora >= datetime.combine(inicio, datetime.min.time()))
        if fim:  # o dia do fim conta inteiro
            q = q.filter(MovimentacaoEstoque.data_hora < datetime.combine(fim + timedelta(days=1), datetime.min.time()))

        total = q.count()
        itens = (
            q.order_by(MovimentacaoEstoque.data_hora.desc(), MovimentacaoEstoque.id_movimentacao.desc())
            .offset((pagina - 1) * limite)
            .limit(limite)
            .all()
        )
        return {
            "itens": [m.virar_dict() for m in itens],
            "total": total,
            "pagina": pagina,
            "limite": limite,
            "tipos": {chave: nome for chave, (nome, _) in MovimentacaoEstoque.TIPOS.items()},
            "origens": MovimentacaoEstoque.ORIGENS,
        }
