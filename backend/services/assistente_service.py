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

    def executar(self, pergunta, historico):
        if not pergunta:
            raise ValueError("pergunta é obrigatória")

        chave = os.getenv("ANTHROPIC_API_KEY")
        if not chave:
            raise ValueError("configure a ANTHROPIC_API_KEY no .env pra usar o assistente")

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
