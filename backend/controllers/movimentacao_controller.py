from flask import Blueprint, request, jsonify

from services.listar_movimentacoes_service import ListarMovimentacoesService

movimentacao_bp = Blueprint("movimentacao", __name__)

FILTROS = ("id_produto", "id_lote", "tipo", "origem", "inicio", "fim", "pagina", "limite")


class MovimentacaoController:

    # /movimentacoes?id_produto=3&tipo=venda&inicio=2026-10-01&fim=2026-10-31&pagina=1&limite=50
    @staticmethod
    def listar():
        try:
            filtros = {chave: request.args.get(chave) for chave in FILTROS}
            return jsonify(ListarMovimentacoesService().executar(filtros))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


movimentacao_bp.add_url_rule("/movimentacoes", view_func=MovimentacaoController.listar, methods=["GET"])
