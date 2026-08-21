from flask import Blueprint, jsonify

from services.listar_reposicao_service import ListarReposicaoService

reposicao_bp = Blueprint("reposicao", __name__)


class ReposicaoController:

    @staticmethod
    def listar():
        return jsonify(ListarReposicaoService().executar())


reposicao_bp.add_url_rule("/reposicao", view_func=ReposicaoController.listar, methods=["GET"])
