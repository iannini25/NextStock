from flask import Blueprint, request, jsonify

from services.sugerir_compras_service import SugerirComprasService

compra_bp = Blueprint("compra", __name__)


class CompraController:

    @staticmethod
    def sugerir():
        try:
            dias = request.args.get("dias", 7)
            clima = request.args.get("clima", "auto")
            return jsonify(SugerirComprasService().executar(dias, clima))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


compra_bp.add_url_rule("/compras/sugestoes", view_func=CompraController.sugerir, methods=["GET"])
