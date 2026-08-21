from flask import Blueprint, request, jsonify

from services.prever_demanda_service import PreverDemandaService

previsao_bp = Blueprint("previsao", __name__)


class PrevisaoController:

    @staticmethod
    def prever():
        try:
            dias = request.args.get("dias", 7)
            clima = request.args.get("clima", "normal")
            return jsonify(PreverDemandaService().executar(dias, clima))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


previsao_bp.add_url_rule("/previsao", view_func=PrevisaoController.prever, methods=["GET"])
