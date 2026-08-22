import os
from datetime import date, timedelta

from google import genai
from google.genai import types

from services.listar_produtos_service import ListarProdutosService
from services.listar_produtos_vencendo_service import ListarProdutosVencendoService
from services.listar_produtos_em_risco_service import ListarProdutosEmRiscoService
from services.montar_painel_service import MontarPainelService
from services.listar_clima_service import ListarClimaService
from services.vendas_em_chuva_service import VendasEmChuvaService


class AssistenteService:

    MODELO = "gemini-3.5-flash"

    def montar_contexto(self):
        linhas = []
        for p in ListarProdutosService().executar():
            linhas.append(
                "- " + str(p["nome"]) + ": estoque " + str(p["quantidade_estoque"]) + " " + str(p["unidade"])
                + ", mínimo " + str(p["estoque_minimo"])
                + ", validade " + str(p["data_validade"])
                + ", preço R$ " + str(p["preco_venda"])
            )

        vencendo = []
        for p in ListarProdutosVencendoService().executar(7):
            vencendo.append(p["nome"])
        linhas.append("Vencendo em 7 dias: " + ", ".join(vencendo))

        em_risco = []
        for p in ListarProdutosEmRiscoService().executar():
            em_risco.append(p["nome"])
        linhas.append("Em risco de faltar: " + ", ".join(em_risco))

        painel = MontarPainelService().executar()
        linhas.append("Painel: " + str(painel))

        hoje = date.today()
        clima = ListarClimaService().executar(hoje - timedelta(days=14), hoje + timedelta(days=7))
        linhas.append("Clima em " + clima["cidade"] + " (fonte: " + clima["fonte"] + "):")
        if clima.get("aviso"):
            linhas.append("- aviso: " + str(clima["aviso"]))
        if clima["dias"]:
            for d in clima["dias"]:
                linhas.append(
                    "- " + str(d["data"]) + ": " + str(d["condicao"])
                    + ", temp " + str(d["temperatura"]) + "°C"
                    + ", chuva " + str(d["chuva_mm"]) + " mm"
                )
        else:
            linhas.append("- sem dados de clima")

        chuva = VendasEmChuvaService().executar(30)
        linhas.append(
            "Dias de chuva (últimos 30): " + (", ".join(chuva["dias_chuva"]) if chuva["dias_chuva"] else "nenhum")
        )
        linhas.append(
            "Dias de chuva forte: "
            + (", ".join(chuva["dias_chuva_forte"]) if chuva["dias_chuva_forte"] else "nenhum")
        )
        if chuva["vendas_chuva"]:
            linhas.append("Vendas nos dias de chuva:")
            for item in chuva["vendas_chuva"]:
                linhas.append(
                    "- " + item["produto_nome"] + ": " + str(item["quantidade"]) + " " + str(item["unidade"] or "")
                )
        else:
            linhas.append("Vendas nos dias de chuva: nenhuma")
        if chuva["vendas_chuva_forte"]:
            linhas.append("Vendas nos dias de chuva forte:")
            for item in chuva["vendas_chuva_forte"]:
                linhas.append(
                    "- " + item["produto_nome"] + ": " + str(item["quantidade"]) + " " + str(item["unidade"] or "")
                )

        return "\n".join(linhas)

    def responder_simples(self, pergunta):
        texto = (pergunta or "").lower()
        if "vencer" in texto or "validade" in texto:
            nomes = [p["nome"] for p in ListarProdutosVencendoService().executar(7)]
            if not nomes:
                return "Nenhum produto vencendo nos próximos 7 dias."
            return "Produtos vencendo em 7 dias: " + ", ".join(nomes)
        if "faltar" in texto or "ruptura" in texto or "acabar" in texto:
            nomes = [p["nome"] for p in ListarProdutosEmRiscoService().executar()]
            if not nomes:
                return "Nenhum produto em risco de faltar."
            return "Produtos em risco de faltar: " + ", ".join(nomes)
        if "desperd" in texto or "perda" in texto or "painel" in texto:
            painel = MontarPainelService().executar()
            return (
                "Desperdício: " + str(painel["percentual_desperdicio"]) + "% • "
                "vencidos: " + str(painel["produtos_vencidos"]) +
                " • valor perdido: R$ " + str(painel["valor_vencido"])
            )
        if (
            "chuva" in texto or "choveu" in texto or "chover" in texto
            or "clima" in texto or "tempo" in texto or "calor" in texto or "frio" in texto
        ):
            return VendasEmChuvaService().texto() + "\n" + ListarClimaService().texto_proximos()
        if "estoque" in texto or "produto" in texto:
            linhas = []
            for p in ListarProdutosService().executar():
                linhas.append(str(p["nome"]) + ": " + str(p["quantidade_estoque"]) + " " + str(p["unidade"]))
            if not linhas:
                return "Não tem produto cadastrado."
            return "Estoque atual:\n" + "\n".join(linhas)
        return (
            "Posso ajudar com validade, risco de faltar, desperdício, estoque e clima/chuva. "
            "Pergunta usando uma dessas palavras."
        )

    def executar(self, pergunta, historico):
        if not pergunta:
            raise ValueError("pergunta é obrigatória")

        chave = os.getenv("GEMINI_API_KEY")
        if not chave or chave == "sua_chave":
            return {"resposta": self.responder_simples(pergunta)}

        contexto = self.montar_contexto()
        instrucoes = (
            "Você é o assistente do NextStock, sistema de estoque de produtos perecíveis "
            "de mercados, padarias e hortifrutis. Responda em português, curto e prático, "
            "usando só os dados abaixo. Se não tiver o dado, diga que não tem. "
            "Se perguntarem de chuva, clima ou tempo, use o clima e as vendas nos dias de chuva."
            "\n\nDADOS DO ESTOQUE:\n" + contexto
        )

        mensagens = []
        for m in historico or []:
            papel = "user" if m.get("papel") == "usuario" else "model"
            mensagens.append(types.Content(
                role=papel,
                parts=[types.Part(text=m.get("texto") or "")],
            ))
        mensagens.append(types.Content(
            role="user",
            parts=[types.Part(text=pergunta)],
        ))

        cliente = genai.Client(api_key=chave)
        resposta = cliente.models.generate_content(
            model=self.MODELO,
            contents=mensagens,
            config=types.GenerateContentConfig(
                system_instruction=instrucoes,
                max_output_tokens=4096,
            ),
        )
        return {"resposta": resposta.text or ""}
