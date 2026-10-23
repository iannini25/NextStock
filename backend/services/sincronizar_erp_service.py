import json
from datetime import datetime, timedelta

from models.database import db
from models.sincronizacao_erp_model import SincronizacaoErp
from repositories.sincronizacao_erp_repository import SincronizacaoErpRepository
from services.erp import fabrica
from services.erp.conector_erp import ErroErp
from services.importar_erp_service import ImportarErpService

# volta um pouco no tempo a cada busca, pra nao perder nada que o ERP gravou bem na virada
# (o que vier repetido nao faz mal: produto so e atualizado e venda repetida e ignorada)
MARGEM = timedelta(minutes=10)
# uma sincronizacao "em andamento" ha mais tempo que isso e considerada travada
TEMPO_MAXIMO = timedelta(minutes=10)


class SincronizarErpService:

    def __init__(self, repo=None, conector=None, importador=None, agora=None):
        self.repo = repo if repo is not None else SincronizacaoErpRepository()
        self.conector = conector if conector is not None else fabrica.criar_conector
        self.importador = importador if importador is not None else ImportarErpService(modo="sincronizacao")
        self.agora = agora if agora is not None else datetime.now

    # busca no ERP o que mudou desde a ultima sincronizacao sem erros e grava no NextStock.
    # sempre registra no historico; se o ERP falhar, o registro fica com status "erro" e a ErroErp sobe.
    def executar(self, usuario=None):
        conector, config = self.conector()
        if not config.ativo:
            raise ValueError("a integração com o ERP está desligada (ligue em Integração ativa)")
        andamento = self.repo.em_andamento()
        if andamento and self.agora() - andamento.iniciado_em < TEMPO_MAXIMO:
            raise ValueError("já tem uma sincronização em andamento, espere ela terminar")

        ultima = self.repo.ultima_com_sucesso()
        desde = ultima.iniciado_em - MARGEM if ultima else None

        sinc = SincronizacaoErp(iniciado_em=self.agora(), status="em_andamento",
                                id_usuario=usuario.id_usuario if usuario else None)
        sinc.salvar()
        try:
            produtos = conector.buscar_produtos(desde)
            vendas = conector.buscar_vendas(desde)
            # produtos antes das vendas: venda de produto novo precisa do produto ja cadastrado
            resultado = self.importador.importar(produtos, vendas)
        except ErroErp as e:
            db.session.rollback()
            self.finalizar(sinc, "erro", erros=[str(e)])
            raise
        except Exception as e:  # erro inesperado: registra pra nao ficar "em andamento" pra sempre
            db.session.rollback()
            self.finalizar(sinc, "erro", erros=["erro inesperado ao gravar os dados: " + type(e).__name__])
            raise

        sinc.produtos_criados = resultado["produtos_criados"]
        sinc.produtos_atualizados = resultado["produtos_atualizados"]
        sinc.vendas_importadas = resultado["vendas_importadas"]
        sinc.vendas_ja_importadas = resultado["vendas_ja_importadas"]
        self.finalizar(sinc, "parcial" if resultado["erros"] else "sucesso", erros=resultado["erros"])
        return sinc.virar_dict()

    def finalizar(self, sinc, status, erros):
        sinc.status = status
        sinc.erros = json.dumps(erros, ensure_ascii=False) if erros else None
        sinc.finalizado_em = self.agora()
        sinc.salvar()
