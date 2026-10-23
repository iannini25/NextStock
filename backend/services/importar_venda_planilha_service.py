from services.formato_planilha import _texto, _numero, _data
from services.utils import inteiro
from datetime import date
from models.produto_model import Produto
from services.registrar_venda_service import RegistrarVendaService


class ImportarVendaPlanilhaService:

    def executar(self, item):
        id_produto = inteiro(_texto(item.get("id_produto")))
        if not id_produto:
            raise ValueError("id_produto é obrigatório")
        if not Produto.buscar_por_id(id_produto):
            raise ValueError("produto não existe")
        quantidade = inteiro(_texto(item.get("quantidade")))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        data_venda = _data(item.get("data_venda")) or date.today()
        RegistrarVendaService().executar({
            "id_produto": id_produto,
            "quantidade": quantidade,
            "data_venda": data_venda.isoformat(),
        }, origem="planilha")
        return "ok"
