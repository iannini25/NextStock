from flask import Blueprint, request, jsonify

from services.registrar_perda_service import RegistrarPerdaService
from services.listar_perdas_service import ListarPerdasService
from services.resumo_perdas_service import ResumoPerdasService

perda_bp = Blueprint("perda", __name__)


# perdas e descartes sao operacao do dia a dia: admin e usuario comum podem registrar e consultar
class PerdaController:

    @staticmethod
    def registrar():
        try:
            return jsonify(RegistrarPerdaService().executar(request.get_json() or {})), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # /perdas?inicio=2026-10-01&fim=2026-10-31&motivo=vencimento&tipo=descarte&id_produto=3
    @staticmethod
    def listar():
        try:
            filtros = {chave: request.args.get(chave) for chave in ("inicio", "fim", "motivo", "tipo", "id_produto")}
            return jsonify(ListarPerdasService().executar(filtros))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def resumo():
        try:
            return jsonify(ResumoPerdasService().executar(request.args.get("dias", 30)))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


perda_bp.add_url_rule("/perdas", view_func=PerdaController.registrar, methods=["POST"])
perda_bp.add_url_rule("/perdas", view_func=PerdaController.listar, methods=["GET"])
perda_bp.add_url_rule("/perdas/resumo", view_func=PerdaController.resumo, methods=["GET"])
