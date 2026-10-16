import json
from datetime import datetime, timedelta

from models.database import db
from models.sincronizacao_erp_model import SincronizacaoErp
from services.erp import fabrica
from services.erp.conector_erp import ErroErp
from services.importar_erp_service import ImportarErpService

# volta um pouco no tempo a cada busca, pra nao perder nada que o ERP gravou bem na virada
# (o que vier repetido nao faz mal: produto so e atualizado e venda repetida e ignorada)
MARGEM = timedelta(minutes=10)
# uma sincronizacao "em andamento" ha mais tempo que isso e considerada travada
TEMPO_MAXIMO = timedelta(minutes=10)


class SincronizarErpService:

    # busca no ERP o que mudou desde a ultima sincronizacao sem erros e grava no NextStock.
    # sempre registra no historico; se o ERP falhar, o registro fica com status "erro" e a ErroErp sobe.
    def executar(self, usuario=None):
        conector, config = fabrica.criar_conector()
        if not config.ativo:
            raise ValueError("a integração com o ERP está desligada (ligue em Integração ativa)")
        andamento = SincronizacaoErp.query.filter_by(status="em_andamento").first()
        if andamento and datetime.now() - andamento.iniciado_em < TEMPO_MAXIMO:
            raise ValueError("já tem uma sincronização em andamento, espere ela terminar")

        ultima = SincronizacaoErp.ultima_com_sucesso()
        desde = ultima.iniciado_em - MARGEM if ultima else None

        sinc = SincronizacaoErp(iniciado_em=datetime.now(), status="em_andamento",
                                id_usuario=usuario.id_usuario if usuario else None)
        sinc.salvar()
        try:
            produtos = conector.buscar_produtos(desde)
            vendas = conector.buscar_vendas(desde)
            # produtos antes das vendas: venda de produto novo precisa do produto ja cadastrado
            resultado = ImportarErpService(modo="sincronizacao").importar(produtos, vendas)
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

    @staticmethod
    def finalizar(sinc, status, erros):
        sinc.status = status
        sinc.erros = json.dumps(erros, ensure_ascii=False) if erros else None
        sinc.finalizado_em = datetime.now()
        sinc.salvar()
