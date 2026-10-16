from tests.fabricas import criar_produto, dia

# sem GEMINI_API_KEY (conftest) o assistente responde pelas regras simples, sem chamar a IA


def perguntar(client, pergunta):
    r = client.post("/assistente", json={"pergunta": pergunta, "historico": []})
    assert r.status_code == 200
    return r.get_json()["resposta"]


def test_sem_pergunta(client):
    r = client.post("/assistente", json={})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "pergunta é obrigatória"}


def test_pergunta_sobre_vencimento(client):
    assert perguntar(client, "o que vai vencer?") == "Nenhum produto vencendo nos próximos 7 dias."
    criar_produto("Iogurte", data_validade=dia(2))
    assert perguntar(client, "o que vai vencer?") == "Produtos vencendo em 7 dias: Iogurte"


def test_pergunta_sobre_estoque(client):
    criar_produto("Leite", quantidade_estoque=10)
    assert perguntar(client, "qual o estoque?") == "Estoque atual:\nLeite: 10 UN"


def test_pergunta_fora_do_assunto(client):
    assert perguntar(client, "bom dia").startswith("Posso ajudar com validade")
