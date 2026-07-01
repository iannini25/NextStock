# NextStock — App (Flutter)

App em Flutter que consome a API do NextStock. É a tela do sistema: lista, cadastra, edita e
exclui **produtos** e **categorias**.

Feito simples de propósito: só `StatefulWidget` + `setState` (sem BLoC, Provider, etc.) e o
pacote `http` pras chamadas na API.

## Estrutura

```
lib/
├── main.dart                 # entrada do app, tema (cores da marca) e as duas abas
├── models/
│   ├── produto.dart          # classe Produto (fromJson/toJson)
│   └── categoria.dart        # classe Categoria (fromJson/toJson)
├── services/
│   └── api_service.dart      # todas as chamadas http + tratamento de erro
└── screens/
    ├── produtos_screen.dart  # lista de produtos
    ├── produto_form.dart     # formulario de criar/editar produto
    ├── categorias_screen.dart
    └── categoria_form.dart
```

## Como rodar

Antes de tudo, a **API** (`backend/`) e o **proxy** (`proxy/`) precisam estar rodando. Veja o
README da raiz do projeto.

Depois:

```bash
flutter pub get
flutter run            # ou: flutter run -d chrome
```

## Endereço da API

No arquivo `lib/services/api_service.dart` tem a constante `baseUrl`. Ela aponta pro **proxy**
(porta 8000), não direto pra API:

- Web e Desktop: `http://127.0.0.1:8000`
- Emulador Android: troque pra `http://10.0.2.2:8000` (o `10.0.2.2` é o localhost do PC visto de
  dentro do emulador)

## Conferir se está ok

```bash
flutter analyze
```
