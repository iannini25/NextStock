from datetime import date, timedelta

from flask import Blueprint, request, jsonify

from services.prever_demanda_service import PreverDemandaService
from services.listar_clima_service import ListarClimaService

previsao_bp = Blueprint("previsao", __name__)


class PrevisaoController:

    @staticmethod
    def prever():
        try:
            dias = request.args.get("dias", 7)
            clima = request.args.get("clima", "auto")
            previsoes = PreverDemandaService().executar(dias, clima)
            try:
                n_dias = int(dias)
            except (TypeError, ValueError):
                n_dias = 7
            hoje = date.today()
            clima_dados = ListarClimaService().executar(hoje + timedelta(days=1), hoje + timedelta(days=n_dias))
            return jsonify({
                "cidade": clima_dados["cidade"],
                "fonte": clima_dados["fonte"],
                "clima": clima,
                "clima_dias": clima_dados["dias"],
                "previsoes": previsoes,
            })
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


previsao_bp.add_url_rule("/previsao", view_func=PrevisaoController.prever, methods=["GET"])
