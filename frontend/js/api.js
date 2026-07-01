// endereco da api (flask)
const URL = "http://127.0.0.1:5000";

// funcao que fala com a api, todas as telas usam
async function api(metodo, rota, corpo) {
  const opcoes = { method: metodo, headers: { "Content-Type": "application/json" } };
  if (corpo) opcoes.body = JSON.stringify(corpo);

  const r = await fetch(URL + rota, opcoes);

  if (r.status === 204) return null; // delete nao volta nada

  const dados = await r.json();
  if (!r.ok) throw new Error(dados.erro || "deu erro");
  return dados;
}
