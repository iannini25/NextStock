from flask import Blueprint, jsonify

from services.listar_clima_service import ListarClimaService

clima_bp = Blueprint("clima", __name__)


class ClimaController:

    @staticmethod
    def listar():
        return jsonify(ListarClimaService().executar())


clima_bp.add_url_rule("/clima", view_func=ClimaController.listar, methods=["GET"])
