let listaCategorias = [];
let editando = null;

window.addEventListener("DOMContentLoaded", () => {
  pegarCategorias();
  document.getElementById("form-categoria").addEventListener("submit", salvar);
  document.getElementById("btn-cancelar").addEventListener("click", limpar);
});

async function pegarCategorias() {
  try {
    listaCategorias = await api("GET", "/categorias");
    montarTabela();
  } catch (e) {
    document.getElementById("tabela-categorias").innerHTML =
      `<tr><td colspan="3">Erro: ${e.message}</td></tr>`;
  }
}

function montarTabela() {
  const corpo = document.getElementById("tabela-categorias");
  if (listaCategorias.length === 0) {
    corpo.innerHTML = '<tr><td colspan="3">Nenhuma categoria cadastrada.</td></tr>';
    return;
  }
  corpo.innerHTML = listaCategorias
    .map(
      (c) => `
      <tr>
        <td>${c.nome}</td>
        <td>${c.descricao || "-"}</td>
        <td class="acoes">
          <button onclick="editar(${c.id_categoria})">Editar</button>
          <button class="excluir" onclick="excluir(${c.id_categoria})">Excluir</button>
        </td>
      </tr>`
    )
    .join("");
}

async function salvar(ev) {
  ev.preventDefault();
  const c = {
    nome: document.getElementById("nome").value,
    descricao: document.getElementById("descricao").value,
  };
  try {
    if (editando === null) await api("POST", "/categorias", c);
    else await api("PUT", "/categorias/" + editando, c);
    limpar();
    pegarCategorias();
  } catch (e) {
    alert(e.message);
  }
}

function editar(id) {
  const c = listaCategorias.find((x) => x.id_categoria === id);
  if (!c) return;
  editando = id;
  document.getElementById("nome").value = c.nome;
  document.getElementById("descricao").value = c.descricao || "";
  document.getElementById("titulo-form").textContent = "Editar categoria";
  document.getElementById("btn-cancelar").style.display = "inline-block";
  window.scrollTo(0, 0);
}

async function excluir(id) {
  const c = listaCategorias.find((x) => x.id_categoria === id);
  if (!confirm(`Excluir a categoria "${c.nome}"?`)) return;
  try {
    await api("DELETE", "/categorias/" + id);
    pegarCategorias();
  } catch (e) {
    alert(e.message);
  }
}

function limpar() {
  editando = null;
  document.getElementById("form-categoria").reset();
  document.getElementById("titulo-form").textContent = "Nova categoria";
  document.getElementById("btn-cancelar").style.display = "none";
}
