from io import BytesIO
from openpyxl import Workbook
from services.formato_planilha import configurar_modulo


class GerarModeloPlanilhaService:

    def executar(self, modulo):
        modulo = (modulo or "").strip().lower()
        cfg = configurar_modulo(modulo)
        wb = Workbook()
        ws = wb.active
        ws.title = modulo
        ws.append(cfg["colunas"])
        ws.append(cfg["exemplo"])
        bio = BytesIO()
        wb.save(bio)
        bio.seek(0)
        return bio, f"modelo_{modulo}.xlsx"
