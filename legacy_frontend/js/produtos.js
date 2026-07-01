let listaProdutos = [];
let editando = null; // null = novo, id = editando

window.addEventListener("DOMContentLoaded", () => {
  pegarCategorias();
  pegarProdutos();
  document.getElementById("form-produto").addEventListener("submit", salvar);
  document.getElementById("btn-cancelar").addEventListener("click", limpar);
});

// carrega as categorias pro select
async function pegarCategorias() {
  try {
    const cats = await api("GET", "/categorias");
    const sel = document.getElementById("id_categoria");
    sel.innerHTML =
      '<option value="">Sem categoria</option>' +
      cats.map((c) => `<option value="${c.id_categoria}">${c.nome}</option>`).join("");
  } catch (e) {
    alert(e.message);
  }
}

async function pegarProdutos() {
  try {
    listaProdutos = await api("GET", "/produtos");
    montarTabela();
  } catch (e) {
    document.getElementById("tabela-produtos").innerHTML =
      `<tr><td colspan="6">Erro: ${e.message}</td></tr>`;
  }
}

function montarTabela() {
  const corpo = document.getElementById("tabela-produtos");
  if (listaProdutos.length === 0) {
    corpo.innerHTML = '<tr><td colspan="6">Nenhum produto cadastrado.</td></tr>';
    return;
  }
  corpo.innerHTML = listaProdutos
    .map(
      (p) => `
      <tr>
        <td>${p.nome}</td>
        <td>${p.categoria_nome || "-"}</td>
        <td>R$ ${Number(p.preco_venda).toFixed(2)}</td>
        <td>${p.quantidade_estoque} ${p.unidade}</td>
        <td>${formatarData(p.data_validade)}</td>
        <td class="acoes">
          <button onclick="editar(${p.id_produto})">Editar</button>
          <button class="excluir" onclick="excluir(${p.id_produto})">Excluir</button>
        </td>
      </tr>`
    )
    .join("");
}

async function salvar(ev) {
  ev.preventDefault();
  const p = {
    nome: document.getElementById("nome").value,
    id_categoria: document.getElementById("id_categoria").value,
    codigo_barras: document.getElementById("codigo_barras").value,
    preco_custo: document.getElementById("preco_custo").value,
    preco_venda: document.getElementById("preco_venda").value,
    quantidade_estoque: document.getElementById("quantidade_estoque").value,
    unidade: document.getElementById("unidade").value,
    data_validade: document.getElementById("data_validade").value,
  };
  try {
    if (editando === null) await api("POST", "/produtos", p);
    else await api("PUT", "/produtos/" + editando, p);
    limpar();
    pegarProdutos();
  } catch (e) {
    alert(e.message);
  }
}

function editar(id) {
  const p = listaProdutos.find((x) => x.id_produto === id);
  if (!p) return;
  editando = id;
  document.getElementById("nome").value = p.nome;
  document.getElementById("id_categoria").value = p.id_categoria || "";
  document.getElementById("codigo_barras").value = p.codigo_barras || "";
  document.getElementById("preco_custo").value = p.preco_custo ?? "";
  document.getElementById("preco_venda").value = p.preco_venda ?? "";
  document.getElementById("quantidade_estoque").value = p.quantidade_estoque ?? "";
  document.getElementById("unidade").value = p.unidade || "UN";
  document.getElementById("data_validade").value = p.data_validade || "";
  document.getElementById("titulo-form").textContent = "Editar produto";
  document.getElementById("btn-cancelar").style.display = "inline-block";
  window.scrollTo(0, 0);
}

async function excluir(id) {
  const p = listaProdutos.find((x) => x.id_produto === id);
  if (!confirm(`Excluir o produto "${p.nome}"?`)) return;
  try {
    await api("DELETE", "/produtos/" + id);
    pegarProdutos();
  } catch (e) {
    alert(e.message);
  }
}

function limpar() {
  editando = null;
  document.getElementById("form-produto").reset();
  document.getElementById("titulo-form").textContent = "Novo produto";
  document.getElementById("btn-cancelar").style.display = "none";
}

// 2026-07-10 vira 10/07/2026
function formatarData(iso) {
  if (!iso) return "-";
  const [a, m, d] = iso.split("-");
  return `${d}/${m}/${a}`;
}
