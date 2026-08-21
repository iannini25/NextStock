import os

import anthropic

from services.listar_produtos_service import ListarProdutosService
from services.listar_produtos_vencendo_service import ListarProdutosVencendoService
from services.listar_produtos_em_risco_service import ListarProdutosEmRiscoService
from services.montar_painel_service import MontarPainelService


class AssistenteService:

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
        if "estoque" in texto or "produto" in texto:
            linhas = []
            for p in ListarProdutosService().executar():
                linhas.append(str(p["nome"]) + ": " + str(p["quantidade_estoque"]) + " " + str(p["unidade"]))
            if not linhas:
                return "Não tem produto cadastrado."
            return "Estoque atual:\n" + "\n".join(linhas)
        return (
            "Posso ajudar com validade, risco de faltar, desperdício e estoque. "
            "Pergunta usando uma dessas palavras."
        )

    def executar(self, pergunta, historico):
        if not pergunta:
            raise ValueError("pergunta é obrigatória")

        chave = os.getenv("ANTHROPIC_API_KEY")
        if not chave or chave == "sua_chave":
            return {"resposta": self.responder_simples(pergunta)}

        contexto = self.montar_contexto()
        instrucoes = (
            "Você é o assistente do NextStock, sistema de estoque de produtos perecíveis "
            "de mercados, padarias e hortifrutis. Responda em português, curto e prático, "
            "usando só os dados abaixo. Se não tiver o dado, diga que não tem."
            "\n\nDADOS DO ESTOQUE:\n" + contexto
        )

        mensagens = []
        for m in historico or []:
            papel = "user" if m.get("papel") == "usuario" else "assistant"
            mensagens.append({"role": papel, "content": m.get("texto") or ""})
        mensagens.append({"role": "user", "content": pergunta})

        cliente = anthropic.Anthropic(api_key=chave)
        resposta = cliente.messages.create(
            model="claude-opus-5",
            max_tokens=4096,
            system=instrucoes,
            messages=mensagens,
        )
        texto = ""
        for bloco in resposta.content:
            if bloco.type == "text":
                texto += bloco.text
        return {"resposta": texto}
