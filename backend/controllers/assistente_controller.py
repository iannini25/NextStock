import anthropic
from flask import Blueprint, request, jsonify

from services.assistente_service import AssistenteService

assistente_bp = Blueprint("assistente", __name__)


class AssistenteController:

    @staticmethod
    def perguntar():
        try:
            dados = request.get_json() or {}
            pergunta = dados.get("pergunta")
            historico = dados.get("historico") or []
            return jsonify(AssistenteService().executar(pergunta, historico))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        except anthropic.APIError as e:
            return jsonify({"erro": "erro ao falar com a IA: " + str(e)}), 502


assistente_bp.add_url_rule("/assistente", view_func=AssistenteController.perguntar, methods=["POST"])
