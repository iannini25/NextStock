from flask import Blueprint, request, jsonify

from services.alertas_excesso_service import AlertasExcessoService
from services.resumo_alertas_service import ResumoAlertasService

alerta_bp = Blueprint("alerta", __name__)


class AlertaController:

    # /alertas/excesso?dias_cobertura=30
    @staticmethod
    def excesso():
        try:
            return jsonify(AlertasExcessoService().executar(request.args.get("dias_cobertura", 30)))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # contagem por tipo, pro selo do menu
    @staticmethod
    def resumo():
        return jsonify(ResumoAlertasService().executar())


alerta_bp.add_url_rule("/alertas/excesso", view_func=AlertaController.excesso, methods=["GET"])
alerta_bp.add_url_rule("/alertas/resumo", view_func=AlertaController.resumo, methods=["GET"])
