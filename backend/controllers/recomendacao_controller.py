from flask import Blueprint, jsonify

from services.gerar_recomendacoes_service import GerarRecomendacoesService

recomendacao_bp = Blueprint("recomendacao", __name__)


class RecomendacaoController:

    @staticmethod
    def listar():
        return jsonify(GerarRecomendacoesService().executar())


recomendacao_bp.add_url_rule("/recomendacoes", view_func=RecomendacaoController.listar, methods=["GET"])
