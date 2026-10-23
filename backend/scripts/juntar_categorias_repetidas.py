"""Prévia: python -m scripts.juntar_categorias_repetidas. Gravar: --aplicar."""
import sys

from services.consolidar_categorias_service import ConsolidarCategoriasService


def juntar_categorias_repetidas(aplicar=False):
    return ConsolidarCategoriasService().executar(aplicar)


if __name__ == "__main__":
    from app import app

    aplicar = "--aplicar" in sys.argv
    with app.app_context():
        resultado = juntar_categorias_repetidas(aplicar)
        for fica, ids, movidos in resultado:
            print(f'"{fica.nome}": fica o id {fica.id_categoria}, sai(em) {ids}, {movidos} produto(s) movido(s)')
        if not resultado:
            print("Nenhuma categoria repetida.")
        elif not aplicar:
            print("Nada foi alterado. Use --aplicar para gravar.")
