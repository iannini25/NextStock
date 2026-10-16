from flask import Blueprint, request, jsonify

from services.listar_usuarios_service import ListarUsuariosService
from services.criar_usuario_service import CriarUsuarioService
from services.atualizar_usuario_service import AtualizarUsuarioService
from services.desativar_usuario_service import DesativarUsuarioService

usuario_bp = Blueprint("usuario", __name__)


class UsuarioController:

    @staticmethod
    def listar():
        return jsonify(ListarUsuariosService().executar())

    @staticmethod
    def criar():
        try:
            u = CriarUsuarioService().executar(request.get_json() or {})
            return jsonify(u), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def atualizar(id):
        try:
            u = AtualizarUsuarioService().executar(id, request.get_json() or {})
            if not u:
                return jsonify({"erro": "usuário não encontrado"}), 404
            return jsonify(u)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # DELETE desativa o usuario, nao apaga
    @staticmethod
    def desativar(id):
        if not DesativarUsuarioService().executar(id):
            return jsonify({"erro": "usuário não encontrado"}), 404
        return "", 204


usuario_bp.add_url_rule("/usuarios", view_func=UsuarioController.listar, methods=["GET"])
usuario_bp.add_url_rule("/usuarios", view_func=UsuarioController.criar, methods=["POST"])
usuario_bp.add_url_rule("/usuarios/<int:id>", view_func=UsuarioController.atualizar, methods=["PUT"])
usuario_bp.add_url_rule("/usuarios/<int:id>", view_func=UsuarioController.desativar, methods=["DELETE"])
