from flask import Blueprint, request, jsonify

from services.montar_relatorio_consumo_service import MontarRelatorioConsumoService
from services.montar_relatorio_desempenho_service import MontarRelatorioDesempenhoService
from services.montar_relatorio_tendencias_service import MontarRelatorioTendenciasService

relatorio_bp = Blueprint("relatorio", __name__)


class RelatorioController:

    @staticmethod
    def consumo():
        try:
            dias = request.args.get("dias", 30)
            return jsonify(MontarRelatorioConsumoService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def desempenho():
        try:
            dias = request.args.get("dias", 30)
            return jsonify(MontarRelatorioDesempenhoService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def tendencias():
        try:
            dias = request.args.get("dias", 30)
            return jsonify(MontarRelatorioTendenciasService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


relatorio_bp.add_url_rule("/relatorios/consumo", view_func=RelatorioController.consumo, methods=["GET"])
relatorio_bp.add_url_rule("/relatorios/desempenho", view_func=RelatorioController.desempenho, methods=["GET"])
relatorio_bp.add_url_rule("/relatorios/tendencias", view_func=RelatorioController.tendencias, methods=["GET"])
