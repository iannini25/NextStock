# NextStock - App (Flutter)

App em Flutter que consome a API do NextStock. E por aqui que o usuario faz tudo: login,
cadastro de produtos e categorias, lotes, vendas, perdas, alertas, relatorios e o resto.

Feito simples de proposito: so `StatefulWidget` com `setState` (sem BLoC, Provider e afins) e o
pacote `http` para as chamadas na API.

## Estrutura

```
lib/
├── main.dart                  # entrada do app e o tema (cores da marca)
├── shell/                     # menu lateral e a tela de entrada
├── models/                    # as classes do app (fromJson/toJson)
├── services/
│   ├── api_service.dart       # todas as chamadas http e o tratamento de erro
│   └── sessao.dart            # guarda o token de quem esta logado
└── screens/                   # as telas e os formularios
```

## Como rodar

A API (`backend/`) precisa estar rodando antes. Veja o README da raiz do projeto.

```bash
flutter pub get
flutter run -d chrome
```

## Endereco da API

No arquivo `lib/services/api_service.dart` tem a constante `baseUrl`:

* Web e Desktop: `http://127.0.0.1:5000`
* Emulador Android: troque para `http://10.0.2.2:5000` (o `10.0.2.2` e o localhost do PC visto de
  dentro do emulador)

## Conferir se esta ok

```bash
flutter analyze
```
