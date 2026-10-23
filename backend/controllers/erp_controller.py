from flask import Blueprint, g, request, jsonify

from controllers.permissoes import exigir_admin

from services.importar_erp_service import ImportarErpService
from services.buscar_configuracao_erp_service import BuscarConfiguracaoErpService
from services.salvar_configuracao_erp_service import SalvarConfiguracaoErpService
from services.remover_chave_erp_service import RemoverChaveErpService
from services.cripto_service import ChaveDeCriptografiaFaltando
from services.testar_conexao_erp_service import TestarConexaoErpService
from services.sincronizar_erp_service import SincronizarErpService
from services.listar_sincronizacoes_erp_service import ListarSincronizacoesErpService
from services.erp.conector_erp import ErroErp

erp_bp = Blueprint("erp", __name__)


class ErpController:

    @staticmethod
    def importar():
        try:
            resultado = ImportarErpService().executar(request.get_json() or {})
            return jsonify(resultado)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # configuracao da integracao (a chave volta mascarada, ex.: ••••1a2b)
    @staticmethod
    def buscar_configuracao():
        return jsonify(BuscarConfiguracaoErpService().executar())

    @staticmethod
    def salvar_configuracao():
        try:
            return jsonify(SalvarConfiguracaoErpService().executar(request.get_json() or {}, g.usuario))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        except ChaveDeCriptografiaFaltando as e:  # problema no .env do servidor, nao no que a pessoa digitou
            return jsonify({"erro": str(e)}), 500

    @staticmethod
    def remover_chave():
        resultado = RemoverChaveErpService().executar(g.usuario)
        if resultado is None:
            return jsonify({"erro": "integração com ERP ainda não configurada"}), 404
        return jsonify(resultado)


    # 400 = falta configurar algo no NextStock; 502 = o ERP falhou (fora do ar, chave recusada...)
    @staticmethod
    def testar_conexao():
        try:
            return jsonify(TestarConexaoErpService().executar())
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        except ErroErp as e:
            return jsonify({"erro": str(e)}), 502

    @staticmethod
    def sincronizar():
        try:
            return jsonify(SincronizarErpService().executar(g.usuario))
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400
        except ErroErp as e:  # a falha ja ficou registrada no historico
            return jsonify({"erro": str(e)}), 502

    @staticmethod
    def listar_sincronizacoes():
        return jsonify(ListarSincronizacoesErpService().executar())


erp_bp.add_url_rule("/erp/importar", view_func=exigir_admin(ErpController.importar), methods=["POST"])
erp_bp.add_url_rule("/erp/configuracao", view_func=exigir_admin(ErpController.buscar_configuracao), methods=["GET"])
erp_bp.add_url_rule("/erp/configuracao", view_func=exigir_admin(ErpController.salvar_configuracao), methods=["PUT"])
erp_bp.add_url_rule("/erp/configuracao/chave", view_func=exigir_admin(ErpController.remover_chave), methods=["DELETE"])
erp_bp.add_url_rule("/erp/testar-conexao", view_func=exigir_admin(ErpController.testar_conexao), methods=["POST"])
erp_bp.add_url_rule("/erp/sincronizar", view_func=exigir_admin(ErpController.sincronizar), methods=["POST"])
erp_bp.add_url_rule("/erp/sincronizacoes", view_func=exigir_admin(ErpController.listar_sincronizacoes), methods=["GET"])
