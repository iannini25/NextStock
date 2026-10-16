from flask import Blueprint, request, jsonify

from services.listar_lotes_produto_service import ListarLotesProdutoService
from services.registrar_entrada_lote_service import RegistrarEntradaLoteService
from services.corrigir_lote_service import CorrigirLoteService
from services.listar_lotes_vencendo_service import ListarLotesVencendoService

lote_bp = Blueprint("lote", __name__)


# lotes sao operacao do dia a dia: admin e usuario comum podem usar
class LoteController:

    # /produtos/3/lotes?todos=1 (todos = inclui os lotes ja esgotados)
    @staticmethod
    def listar_do_produto(id):
        todos = request.args.get("todos") in ("1", "true", "sim")
        resultado = ListarLotesProdutoService().executar(id, todos)
        if resultado is None:
            return jsonify({"erro": "produto não encontrado"}), 404
        return jsonify(resultado)

    @staticmethod
    def registrar_entrada():
        try:
            return jsonify(RegistrarEntradaLoteService().executar(request.get_json() or {})), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def corrigir(id):
        try:
            resultado = CorrigirLoteService().executar(id, request.get_json() or {})
            if resultado is None:
                return jsonify({"erro": "lote não encontrado"}), 404
            return jsonify(resultado)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def listar_vencendo():
        try:
            return jsonify(ListarLotesVencendoService().executar(request.args.get("dias", 7)))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


lote_bp.add_url_rule("/produtos/<int:id>/lotes", view_func=LoteController.listar_do_produto, methods=["GET"])
lote_bp.add_url_rule("/lotes", view_func=LoteController.registrar_entrada, methods=["POST"])
lote_bp.add_url_rule("/lotes/<int:id>", view_func=LoteController.corrigir, methods=["PUT"])
lote_bp.add_url_rule("/lotes/vencendo", view_func=LoteController.listar_vencendo, methods=["GET"])
