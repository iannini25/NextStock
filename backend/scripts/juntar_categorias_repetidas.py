"""Junta categorias com o mesmo nome (ex.: quando o create_database.sql rodou duas vezes).

Fica a categoria mais antiga (menor id); os produtos das repetidas passam pra ela e as repetidas sao apagadas.

Uso (dentro da pasta backend):
    python -m scripts.juntar_categorias_repetidas            -> so mostra o que faria, nao muda nada
    python -m scripts.juntar_categorias_repetidas --aplicar  -> faz de verdade
"""
import sys

from models.database import db
from models.categoria_model import Categoria
from models.produto_model import Produto


# devolve [(categoria que fica, [ids apagados], produtos movidos)]. so grava se aplicar=True
def juntar_categorias_repetidas(aplicar=False):
    grupos = {}
    for c in Categoria.query.order_by(Categoria.id_categoria).all():
        grupos.setdefault(c.nome.strip().lower(), []).append(c)

    resultado = []
    for categorias in grupos.values():
        if len(categorias) < 2:
            continue
        fica, repetidas = categorias[0], categorias[1:]
        ids = [c.id_categoria for c in repetidas]
        movidos = Produto.query.filter(Produto.id_categoria.in_(ids)).update(
            {Produto.id_categoria: fica.id_categoria}, synchronize_session=False
        )
        for c in repetidas:
            db.session.delete(c)
        resultado.append((fica, ids, movidos))

    if aplicar:
        db.session.commit()
    else:
        db.session.rollback()
    return resultado


if __name__ == "__main__":
    from app import app

    aplicar = "--aplicar" in sys.argv
    with app.app_context():
        resultado = juntar_categorias_repetidas(aplicar)
        if not resultado:
            print("Nenhuma categoria repetida.")
        for fica, ids, movidos in resultado:
            print(f'"{fica.nome}": fica o id {fica.id_categoria}, sai(em) {ids}, {movidos} produto(s) movido(s)')
        if resultado and not aplicar:
            print("\nNada foi alterado. Rode de novo com --aplicar pra fazer de verdade.")
        elif resultado:
            print("\nPronto.")
