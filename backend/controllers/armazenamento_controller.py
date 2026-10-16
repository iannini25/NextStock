from flask import Blueprint, g, request, jsonify

from controllers.permissoes import exigir_admin
from models.database import db
from models.local_armazenamento_model import LocalArmazenamento
from services.alertas_temperatura_service import AlertasTemperaturaService
from services.listar_leituras_service import ListarLeiturasService
from services.registrar_leitura_service import RegistrarLeituraService
from services.salvar_local_service import SalvarLocalService
from services.situacao_local import montar

armazenamento_bp = Blueprint("armazenamento", __name__)

NAO_EXISTE = ({"erro": "local de armazenamento não existe"}, 404)


# locais: todo mundo consulta e registra leitura; criar, editar e desativar e so do admin.
# a leitura tambem pode chegar de um dispositivo, com o header X-Sensor-Key (ver auth_controller)
class ArmazenamentoController:

    # /locais-armazenamento?todos=1 (todos = inclui os desativados)
    @staticmethod
    def listar():
        todos = request.args.get("todos") in ("1", "true", "sim")
        return jsonify([montar(l) for l in LocalArmazenamento.listar(todos=todos)])

    @staticmethod
    def buscar(id):
        local = LocalArmazenamento.buscar_por_id(id)
        if not local:
            return jsonify(NAO_EXISTE[0]), NAO_EXISTE[1]
        return jsonify(montar(local, com_produtos=True))

    @staticmethod
    def criar():
        try:
            return jsonify(SalvarLocalService().executar(request.get_json(silent=True) or {})), 201
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def atualizar(id):
        try:
            local = SalvarLocalService().executar(request.get_json(silent=True) or {}, id=id)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        if local is None:
            return jsonify(NAO_EXISTE[0]), NAO_EXISTE[1]
        return jsonify(local)

    # nao apaga (as leituras e os produtos continuam ligados): so desativa
    @staticmethod
    def desativar(id):
        local = LocalArmazenamento.buscar_por_id(id)
        if not local:
            return jsonify(NAO_EXISTE[0]), NAO_EXISTE[1]
        local.ativo = False
        db.session.commit()
        return jsonify(local.virar_dict())

    # /locais-armazenamento/3/leituras?inicio=2026-10-01&fim=2026-10-16&limite=100
    @staticmethod
    def listar_leituras(id):
        try:
            leituras = ListarLeiturasService().executar(id, request.args)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        if leituras is None:
            return jsonify(NAO_EXISTE[0]), NAO_EXISTE[1]
        return jsonify(leituras)

    @staticmethod
    def registrar_leitura(id):
        origem = "sensor" if g.get("sensor") else "manual"
        try:
            resultado = RegistrarLeituraService().executar(id, request.get_json(silent=True) or {}, origem)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        if resultado is None:
            return jsonify(NAO_EXISTE[0]), NAO_EXISTE[1]
        return jsonify(resultado), 201

    # /armazenamento/alertas?horas=12 (sem leitura ha mais que isso tambem e alerta)
    @staticmethod
    def alertas():
        try:
            return jsonify(AlertasTemperaturaService().executar(request.args.get("horas")))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


C = ArmazenamentoController
armazenamento_bp.add_url_rule("/locais-armazenamento", view_func=C.listar, methods=["GET"])
armazenamento_bp.add_url_rule("/locais-armazenamento", view_func=exigir_admin(C.criar), methods=["POST"])
armazenamento_bp.add_url_rule("/locais-armazenamento/<int:id>", view_func=C.buscar, methods=["GET"])
armazenamento_bp.add_url_rule("/locais-armazenamento/<int:id>", view_func=exigir_admin(C.atualizar), methods=["PUT"])
armazenamento_bp.add_url_rule("/locais-armazenamento/<int:id>", view_func=exigir_admin(C.desativar), methods=["DELETE"])
armazenamento_bp.add_url_rule("/locais-armazenamento/<int:id>/leituras", view_func=C.listar_leituras, methods=["GET"])
armazenamento_bp.add_url_rule("/locais-armazenamento/<int:id>/leituras", view_func=C.registrar_leitura, methods=["POST"])
armazenamento_bp.add_url_rule("/armazenamento/alertas", view_func=C.alertas, methods=["GET"])
