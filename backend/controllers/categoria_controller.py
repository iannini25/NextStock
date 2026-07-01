from flask import Blueprint, request, jsonify

from services.criar_categoria_service import criar_categoria
from services.listar_categorias_service import listar_categorias
from services.buscar_categoria_service import buscar_categoria
from services.atualizar_categoria_service import atualizar_categoria
from services.deletar_categoria_service import deletar_categoria

cat_bp = Blueprint("cat", __name__)


@cat_bp.get("/categorias")
def listar():
    return jsonify(listar_categorias())


@cat_bp.post("/categorias")
def criar():
    try:
        c = criar_categoria(request.get_json() or {})
        return jsonify(c), 201
    except ValueError as e:
        return jsonify({"erro": str(e)}), 400


@cat_bp.get("/categorias/<int:id>")
def buscar(id):
    c = buscar_categoria(id)
    if not c:
        return jsonify({"erro": "categoria não encontrada"}), 404
    return jsonify(c)


@cat_bp.put("/categorias/<int:id>")
def atualizar(id):
    try:
        c = atualizar_categoria(id, request.get_json() or {})
        if not c:
            return jsonify({"erro": "categoria não encontrada"}), 404
        return jsonify(c)
    except ValueError as e:
        return jsonify({"erro": str(e)}), 400


@cat_bp.delete("/categorias/<int:id>")
def deletar(id):
    if not deletar_categoria(id):
        return jsonify({"erro": "categoria não encontrada"}), 404
    return "", 204
