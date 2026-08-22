from flask import Blueprint, jsonify, request, send_file

from services.importar_planilha_service import ImportarPlanilhaService

importar_bp = Blueprint("importar", __name__)


class ImportarController:

    @staticmethod
    def modelo():
        try:
            arquivo, nome = ImportarPlanilhaService().gerar_modelo(request.args.get("modulo", ""))
            return send_file(
                arquivo,
                as_attachment=True,
                download_name=nome,
                mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    @staticmethod
    def importar():
        try:
            modulo = request.args.get("modulo") or request.form.get("modulo") or ""
            resultado = ImportarPlanilhaService().executar(modulo, request.files.get("arquivo"))
            return jsonify(resultado)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400


importar_bp.add_url_rule("/importar/modelo", view_func=ImportarController.modelo, methods=["GET"])
importar_bp.add_url_rule("/importar", view_func=ImportarController.importar, methods=["POST"])
