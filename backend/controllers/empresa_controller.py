from flask import Blueprint, request, jsonify

from services.verificar_setup_service import VerificarSetupService
from services.configurar_empresa_service import ConfigurarEmpresaService
from services.buscar_empresa_service import BuscarEmpresaService
from services.atualizar_empresa_service import AtualizarEmpresaService

empresa_bp = Blueprint("empresa", __name__)


class EmpresaController:

    @staticmethod
    def status_setup():
        return jsonify(VerificarSetupService().executar())

    @staticmethod
    def configurar():
        try:
            resultado = ConfigurarEmpresaService().executar(request.get_json() or {})
            if resultado is None:
                return jsonify({"erro": "a empresa já foi configurada"}), 409
            return jsonify(resultado), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def buscar():
        empresa = BuscarEmpresaService().executar()
        if not empresa:
            return jsonify({"erro": "empresa ainda não configurada"}), 404
        return jsonify(empresa)

    @staticmethod
    def atualizar():
        try:
            empresa = AtualizarEmpresaService().executar(request.get_json() or {})
            if not empresa:
                return jsonify({"erro": "empresa ainda não configurada"}), 404
            return jsonify(empresa)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


empresa_bp.add_url_rule("/setup/status", view_func=EmpresaController.status_setup, methods=["GET"])
empresa_bp.add_url_rule("/setup", view_func=EmpresaController.configurar, methods=["POST"])
empresa_bp.add_url_rule("/empresa", view_func=EmpresaController.buscar, methods=["GET"])
empresa_bp.add_url_rule("/empresa", view_func=EmpresaController.atualizar, methods=["PUT"])
