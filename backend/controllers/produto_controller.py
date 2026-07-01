from flask import Blueprint, request, jsonify

from services.criar_produto_service import criar_produto
from services.listar_produtos_service import listar_produtos
from services.buscar_produto_service import buscar_produto
from services.atualizar_produto_service import atualizar_produto
from services.deletar_produto_service import deletar_produto

prod_bp = Blueprint("prod", __name__)


@prod_bp.get("/produtos")
def listar():
    return jsonify(listar_produtos())


@prod_bp.post("/produtos")
def criar():
    try:
        p = criar_produto(request.get_json() or {})
        return jsonify(p), 201
    except ValueError as e:
        return jsonify({"erro": str(e)}), 400


@prod_bp.get("/produtos/<int:id>")
def buscar(id):
    p = buscar_produto(id)
    if not p:
        return jsonify({"erro": "produto não encontrado"}), 404
    return jsonify(p)


@prod_bp.put("/produtos/<int:id>")
def atualizar(id):
    try:
        p = atualizar_produto(id, request.get_json() or {})
        if not p:
            return jsonify({"erro": "produto não encontrado"}), 404
        return jsonify(p)
    except ValueError as e:
        return jsonify({"erro": str(e)}), 400


@prod_bp.delete("/produtos/<int:id>")
def deletar(id):
    if not deletar_produto(id):
        return jsonify({"erro": "produto não encontrado"}), 404
    return "", 204
