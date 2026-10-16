from datetime import datetime
from decimal import Decimal

from models.database import db
from models.lote_model import Lote
from models.perda_model import Perda
from services.estoque_lote_service import EstoqueLoteService
from services.utils import inteiro, usuario_logado, virar_texto


# registra uma perda ou um descarte de um lote: baixa o lote (com historico) e guarda o valor perdido.
# a perda NAO entra na tabela de vendas, entao nao mexe na previsao nem nos relatorios de venda
class RegistrarPerdaService:

    def executar(self, dados):
        lote = Lote.buscar_por_id(dados.get("id_lote")) if dados.get("id_lote") else None
        if not lote:
            raise ValueError("lote não existe")
        quantidade = inteiro(dados.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        tipo = str(dados.get("tipo") or "perda").strip().lower()
        if tipo not in Perda.TIPOS:
            raise ValueError("tipo tem que ser perda ou descarte")
        motivo = str(dados.get("motivo") or "").strip().lower()
        if motivo not in Perda.MOTIVOS:
            raise ValueError("motivo inválido. use: " + ", ".join(Perda.MOTIVOS))
        observacao = virar_texto(dados.get("observacao"), "observação", 255)

        # o valor e o custo DESTE lote; sem custo no lote, usa o do produto; sem nenhum, fica zero (com aviso)
        produto = lote.produto
        custo = lote.custo_unitario if lote.custo_unitario is not None else produto.preco_custo
        aviso = None
        if custo is None:
            aviso = "esse produto não tem custo cadastrado: o valor da perda ficou R$ 0,00"
        valor = (Decimal(str(custo)) * quantidade) if custo is not None else Decimal("0")

        try:
            texto = Perda.MOTIVOS[motivo] + (": " + observacao if observacao else "")
            movimentacao = EstoqueLoteService().baixar_do_lote(lote, quantidade, tipo, observacao=texto)
            usuario = usuario_logado()
            perda = Perda(
                produto=produto,
                lote=lote,
                tipo=tipo,
                motivo=motivo,
                quantidade=quantidade,
                custo_unitario=custo,
                valor_total=valor,
                observacao=observacao,
                id_usuario=usuario.id_usuario if usuario else None,
                data_registro=datetime.now(),
                movimentacao=movimentacao,
            )
            db.session.add(perda)
            db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return {"perda": perda.virar_dict(), "produto": produto.virar_dict(), "aviso": aviso}
