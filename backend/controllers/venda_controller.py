from flask import Blueprint, request, jsonify

from services.registrar_venda_service import RegistrarVendaService
from services.listar_vendas_service import ListarVendasService
from services.previa_venda_service import PreviaVendaService

venda_bp = Blueprint("venda", __name__)


class VendaController:

    @staticmethod
    def listar():
        try:
            dias = request.args.get("dias", 30)
            return jsonify(ListarVendasService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # /vendas/previa?id_produto=3&quantidade=8 -> de quais lotes a venda sairia (nao grava nada)
    @staticmethod
    def previa():
        try:
            return jsonify(PreviaVendaService().executar(request.args.get("id_produto"), request.args.get("quantidade")))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def registrar():
        try:
            v = RegistrarVendaService().executar(request.get_json() or {})
            return jsonify(v), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


venda_bp.add_url_rule("/vendas/previa", view_func=VendaController.previa, methods=["GET"])
venda_bp.add_url_rule("/vendas", view_func=VendaController.listar, methods=["GET"])
venda_bp.add_url_rule("/vendas", view_func=VendaController.registrar, methods=["POST"])
