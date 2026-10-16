# Super App Flutter — Arquitetura de Micro Apps + Clean Architecture

Super app bancário em **Flutter** organizado em **micro apps**: cada funcionalidade (Extrato, Pix) é um pacote independente, com sua própria **Clean Architecture**, suas tabelas no **SQLite** e seus endpoints **REST**. O app hospedeiro (*shell*) só os compõe. Os micro apps **não se conhecem** e conversam por um **event bus**.

> Segmento: **Bancário** — mesmo modelo de super apps de grandes bancos brasileiros

## Stack
Flutter 3 / Dart 3 (sealed classes, records, pattern matching) • **Pub Workspaces** (monorepo) • **Micro Apps** • **Clean Architecture** • **flutter_bloc** (Cubit) • **get_it** (DI) • **go_router** (ShellRoute) • **Dio** (interceptors) • **sqflite** com migrações por micro app • Equatable • **bloc_test**, **mocktail**, sqflite_common_ffi • Material 3

## Arquitetura

```
apps/shell ─────────────── composition root: registra micro apps, monta rotas/abas, abre o banco
   │                         (adicionar uma funcionalidade = 1 linha em bootstrap.dart)
   ├── packages/micro_statement      packages/micro_pix          ← micro apps (não se importam)
   │      domain/  entidades, contrato, caso de uso                 domain/  PixKey (value object), SendPix
   │      data/    REST (Dio) + SQLite offline-first                 data/    REST + contatos recentes (SQLite)
   │      presentation/ Cubit + páginas                             presentation/ Cubit + página
   │            ▲                                                         │
   │            └──────────── EventBus: PixSentEvent ─────────────────────┘
   │
   ├── packages/core            contrato MicroApp, MicroAppRegistry, EventBus, ApiClient, AppDatabase, Result/Failure
   └── packages/design_system   tema, BalanceCard, AmountText, formatadores (dinheiro em centavos)
```

### Contrato de micro app
```dart
abstract class MicroApp {
  String get name;                              // prefixo obrigatório das tabelas
  MicroAppEntry? get entry;                     // aba na navegação inferior
  List<RouteBase> get routes;                   // rotas contribuídas ao go_router
  Map<int, List<String>> get migrations;        // migrações SQLite por versão
  void registerDependencies(GetIt di);          // DI do próprio micro app
  void listenEvents(GetIt di);                  // reação a eventos de outros micro apps
}
```

### Decisões técnicas
- **Isolamento de dados**: cada micro app só pode criar/alterar tabelas com o próprio prefixo (`statement_*`, `pix_*`). O shell valida isso na inicialização.
- **Comunicação por eventos com payload primitivo**: o extrato recarrega quando um Pix é enviado sem importar nada do micro app de Pix.
- **Offline-first**: o extrato vem da rede e é salvo no SQLite; sem conexão, mostra o último extrato salvo com aviso.
- **Erros como valores** (`Result<T>` + `Failure` selada): a camada de apresentação nunca vê `DioException` nem erros de SQLite.
- **Interceptor central**: um 401 em qualquer micro app publica `SessionExpiredEvent`, e o shell avisa o usuário.
- **Pix idempotente**: a chave de idempotência é reaproveitada no retry, então um timeout não gera débito duplo. O limite noturno do Bacen é validado no caso de uso.
- **Backend simulado** (`MockBackendInterceptor`): cada micro app registra seus endpoints falsos, e o app roda sem servidor.

## Como executar
```bash
flutter pub get                       # resolve o workspace inteiro
cd apps/shell && flutter run
flutter analyze                       # sem issues
for p in packages/* apps/shell; do (cd $p && flutter test); done
```

## Testes (19)
- **core**: event bus tipado, merge de migrações, isolamento de tabelas, mapeamento de erros HTTP e 401.
- **micro_statement**: repositório offline-first com SQLite real (FFI), caso de uso, Cubit.
- **micro_pix**: validação de chaves (CPF/CNPJ/e-mail/celular/EVP), limite noturno, evento publicado, idempotência no retry.
- **shell**: teste ponta a ponta — envia um Pix e verifica que o extrato de outro micro app foi atualizado.
