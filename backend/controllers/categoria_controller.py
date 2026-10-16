from flask import Blueprint, request, jsonify

from controllers.permissoes import exigir_admin

from services.criar_categoria_service import CriarCategoriaService
from services.listar_categorias_service import ListarCategoriasService
from services.buscar_categoria_service import BuscarCategoriaService
from services.atualizar_categoria_service import AtualizarCategoriaService
from services.deletar_categoria_service import DeletarCategoriaService

cat_bp = Blueprint("cat", __name__)


class CategoriaController:

    @staticmethod
    def listar():
        return jsonify(ListarCategoriasService().executar())

    @staticmethod
    def criar():
        try:
            c = CriarCategoriaService().executar(request.get_json() or {})
            return jsonify(c), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def buscar(id):
        c = BuscarCategoriaService().executar(id)
        if not c:
            return jsonify({"erro": "categoria não encontrada"}), 404
        return jsonify(c)

    @staticmethod
    def atualizar(id):
        try:
            c = AtualizarCategoriaService().executar(id, request.get_json() or {})
            if not c:
                return jsonify({"erro": "categoria não encontrada"}), 404
            return jsonify(c)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def deletar(id):
        try:
            if not DeletarCategoriaService().executar(id):
                return jsonify({"erro": "categoria não encontrada"}), 404
            return "", 204
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


# rotas apontando pros metodos da controller
cat_bp.add_url_rule("/categorias", view_func=CategoriaController.listar, methods=["GET"])
cat_bp.add_url_rule("/categorias", view_func=CategoriaController.criar, methods=["POST"])
cat_bp.add_url_rule("/categorias/<int:id>", view_func=CategoriaController.buscar, methods=["GET"])
cat_bp.add_url_rule("/categorias/<int:id>", view_func=CategoriaController.atualizar, methods=["PUT"])
cat_bp.add_url_rule("/categorias/<int:id>", view_func=exigir_admin(CategoriaController.deletar), methods=["DELETE"])
