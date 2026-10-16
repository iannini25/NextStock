from flask import Blueprint, request, jsonify

from controllers.permissoes import exigir_admin

from services.criar_evento_service import CriarEventoService
from services.listar_eventos_service import ListarEventosService
from services.deletar_evento_service import DeletarEventoService

evento_bp = Blueprint("evento", __name__)


class EventoController:

    @staticmethod
    def listar():
        return jsonify(ListarEventosService().executar())

    @staticmethod
    def criar():
        try:
            ev = CriarEventoService().executar(request.get_json() or {})
            return jsonify(ev), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def deletar(id):
        if not DeletarEventoService().executar(id):
            return jsonify({"erro": "evento não encontrado"}), 404
        return "", 204


evento_bp.add_url_rule("/eventos", view_func=EventoController.listar, methods=["GET"])
evento_bp.add_url_rule("/eventos", view_func=EventoController.criar, methods=["POST"])
evento_bp.add_url_rule("/eventos/<int:id>", view_func=exigir_admin(EventoController.deletar), methods=["DELETE"])
