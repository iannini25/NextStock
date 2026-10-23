from services.formato_planilha import MODULOS, configurar_modulo, _texto
from services.ler_planilha_service import LerPlanilhaService
from services.gerar_modelo_planilha_service import GerarModeloPlanilhaService
from services.importar_categoria_planilha_service import ImportarCategoriaPlanilhaService
from services.importar_produto_planilha_service import ImportarProdutoPlanilhaService
from services.importar_venda_planilha_service import ImportarVendaPlanilhaService
from services.importar_evento_planilha_service import ImportarEventoPlanilhaService


class ImportarPlanilhaService:

    def __init__(self, leitor=None, importadores=None):
        self.leitor = leitor if leitor is not None else LerPlanilhaService()
        self.importadores = importadores if importadores is not None else {
            "categorias": ImportarCategoriaPlanilhaService(),
            "produtos": ImportarProdutoPlanilhaService(),
            "vendas": ImportarVendaPlanilhaService(),
            "eventos": ImportarEventoPlanilhaService()
        }

    def executar(self, modulo, arquivo):
        modulo = (modulo or "").strip().lower()
        cfg = configurar_modulo(modulo)
        if arquivo is None or not arquivo.filename:
            raise ValueError("envie um arquivo .csv ou .xlsx")

        nome = arquivo.filename.lower()
        if not (nome.endswith(".csv") or nome.endswith(".xlsx")):
            raise ValueError("o arquivo tem que ser .csv ou .xlsx")

        dados = arquivo.read()
        if not dados:
            raise ValueError("arquivo vazio")

        linhas, cabecalhos = self.leitor.executar(nome, dados)
        faltando = [c for c in cfg["obrigatorias"] if c not in cabecalhos]
        if faltando:
            raise ValueError("faltam as colunas obrigatórias: " + ", ".join(faltando))

        importados = 0
        ignorados = 0
        erros = []

        for i, item in enumerate(linhas, start=2):
            if self._linha_vazia(item, cfg["colunas"]):
                ignorados += 1
                continue
            try:
                resultado = self.importadores[modulo].executar(item)
                if resultado == "ok":
                    importados += 1
                else:
                    ignorados += 1
            except ValueError as e:
                erros.append("Linha " + str(i) + ": " + str(e))

        return {
            "importados": importados,
            "ignorados": ignorados,
            "erros": erros,
        }

    def _linha_vazia(self, item, colunas):
        return all(not _texto(item.get(c)) for c in colunas)

    def gerar_modelo(self, modulo):
        return GerarModeloPlanilhaService().executar(modulo)
