from flask import Blueprint, request, jsonify

from services.importar_erp_service import ImportarErpService

erp_bp = Blueprint("erp", __name__)


class ErpController:

    @staticmethod
    def importar():
        try:
            resultado = ImportarErpService().executar(request.get_json() or {})
            return jsonify(resultado)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


erp_bp.add_url_rule("/erp/importar", view_func=ErpController.importar, methods=["POST"])
