from flask import Blueprint, jsonify

from services.montar_painel_service import MontarPainelService

painel_bp = Blueprint("painel", __name__)


class PainelController:

    @staticmethod
    def montar():
        return jsonify(MontarPainelService().executar())


painel_bp.add_url_rule("/painel", view_func=PainelController.montar, methods=["GET"])
