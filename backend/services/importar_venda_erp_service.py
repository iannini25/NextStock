from datetime import date

from models.database import db
from models.erp_venda_importada_model import ErpVendaImportada
from models.produto_model import Produto
from services.planejar_saida_service import PlanejarSaidaService
from services.registrar_venda_service import RegistrarVendaService
from services.utils import virar_data


class ImportarVendaErpService:
    def __init__(self, sincronizando=False, produto_model=None, importada_model=None, registro=None, hoje=None):
        self.sincronizando = sincronizando
        self.produto_model = produto_model if produto_model is not None else Produto
        self.importada_model = importada_model if importada_model is not None else ErpVendaImportada
        self.registro = registro if registro is not None else RegistrarVendaService()
        self.hoje = hoje if hoje is not None else date.today

    def executar(self, item):
        if not isinstance(item, dict):
            raise ValueError("formato inválido")
        id_externo = None
        if self.sincronizando:
            id_externo = str(item.get("id_externo") or "").strip()
            if not id_externo:
                raise ValueError("venda sem id_externo")
            if len(id_externo) > 100:
                raise ValueError("id_externo pode ter no máximo 100 caracteres")
            if self.importada_model.ja_importada(id_externo):
                return "repetida"
        produto = self.produto_model.buscar_por_codigo(item.get("codigo_barras"))
        if not produto:
            raise ValueError("produto não encontrado")
        quantidade = PlanejarSaidaService.validar_quantidade(item.get("quantidade"))
        data_venda = virar_data(item.get("data_venda")) or self.hoje()
        try:
            dados = {"id_produto": produto.id_produto, "quantidade": quantidade, "data_venda": data_venda.isoformat()}
            if self.sincronizando:
                venda = self.registro.executar(dados, baixar_estoque=False, origem="erp", confirmar=False)
                self.importada_model(id_externo=id_externo, id_venda=venda["id_venda"]).salvar()
            else:
                self.registro.executar(dados, origem="erp")
        except Exception:
            db.session.rollback()
            raise
        return "importada"
