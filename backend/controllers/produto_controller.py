from flask import Blueprint, request, jsonify

from controllers.permissoes import exigir_admin

from services.criar_produto_service import CriarProdutoService
from services.listar_produtos_service import ListarProdutosService
from services.buscar_produto_service import BuscarProdutoService
from services.atualizar_produto_service import AtualizarProdutoService
from services.deletar_produto_service import DeletarProdutoService
from services.listar_produtos_vencendo_service import ListarProdutosVencendoService
from services.listar_produtos_em_risco_service import ListarProdutosEmRiscoService

prod_bp = Blueprint("prod", __name__)


# a controller so pega a requisicao, chama o service e devolve json.
# regra de negocio nenhuma aqui dentro.
class ProdutoController:

    @staticmethod
    def listar():
        return jsonify(ListarProdutosService().executar())

    @staticmethod
    def criar():
        try:
            p = CriarProdutoService().executar(request.get_json() or {})
            return jsonify(p), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def buscar(id):
        p = BuscarProdutoService().executar(id)
        if not p:
            return jsonify({"erro": "produto não encontrado"}), 404
        return jsonify(p)

    @staticmethod
    def atualizar(id):
        try:
            p = AtualizarProdutoService().executar(id, request.get_json() or {})
            if not p:
                return jsonify({"erro": "produto não encontrado"}), 404
            return jsonify(p)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def deletar(id):
        try:
            if not DeletarProdutoService().executar(id):
                return jsonify({"erro": "produto não encontrado"}), 404
            return "", 204
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # /produtos/vencendo?dias=7
    @staticmethod
    def listar_vencendo():
        try:
            dias = request.args.get("dias", 7)
            return jsonify(ListarProdutosVencendoService().executar(dias))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def listar_em_risco():
        return jsonify(ListarProdutosEmRiscoService().executar())


# rotas apontando pros metodos da controller
prod_bp.add_url_rule("/produtos/vencendo", view_func=ProdutoController.listar_vencendo, methods=["GET"])
prod_bp.add_url_rule("/produtos/risco-ruptura", view_func=ProdutoController.listar_em_risco, methods=["GET"])
prod_bp.add_url_rule("/produtos", view_func=ProdutoController.listar, methods=["GET"])
prod_bp.add_url_rule("/produtos", view_func=ProdutoController.criar, methods=["POST"])
prod_bp.add_url_rule("/produtos/<int:id>", view_func=ProdutoController.buscar, methods=["GET"])
prod_bp.add_url_rule("/produtos/<int:id>", view_func=ProdutoController.atualizar, methods=["PUT"])
prod_bp.add_url_rule("/produtos/<int:id>", view_func=exigir_admin(ProdutoController.deletar), methods=["DELETE"])
