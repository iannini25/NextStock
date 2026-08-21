from flask import Blueprint, request, jsonify

from services.registrar_venda_service import RegistrarVendaService
from services.listar_vendas_service import ListarVendasService

venda_bp = Blueprint("venda", __name__)


class VendaController:

    @staticmethod
    def listar():
        try:
            dias = request.args.get("dias", 30)
            return jsonify(ListarVendasService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def registrar():
        try:
            v = RegistrarVendaService().executar(request.get_json() or {})
            return jsonify(v), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


venda_bp.add_url_rule("/vendas", view_func=VendaController.listar, methods=["GET"])
venda_bp.add_url_rule("/vendas", view_func=VendaController.registrar, methods=["POST"])
