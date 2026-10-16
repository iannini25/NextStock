from repositories.produto_repository import ProdutoRepository
from services.alertas_excesso_service import AlertasExcessoService
from services.alertas_temperatura_service import AlertasTemperaturaService
from services.listar_produtos_em_risco_service import ListarProdutosEmRiscoService


# quantos alertas tem de cada tipo, pro selo do menu (o app pergunta isso de tempos em tempos)
class ResumoAlertasService:

    def executar(self):
        vencendo = len(ProdutoRepository().listar_proximos_do_vencimento(7))  # igual a aba Vencendo (7 dias)
        falta = ListarProdutosEmRiscoService().executar()
        excesso = AlertasExcessoService().executar()
        temperatura = AlertasTemperaturaService().executar()  # locais fora da faixa ou sem leitura
        return {
            "vencendo": vencendo,
            "falta": len(falta),
            "excesso": len(excesso),
            "temperatura": len(temperatura),
            "total": vencendo + len(falta) + len(excesso) + len(temperatura),
            "prioridade_alta": sum(1 for a in falta + excesso + temperatura if a["prioridade"] == "alta"),
        }
