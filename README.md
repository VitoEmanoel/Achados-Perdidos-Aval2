# Achados e Perdidos

Aplicativo de achados e perdidos do campus da UESPI, desenvolvido para a disciplina Programação para Dispositivos Móveis.

## Integrantes

- Victor Emanoel Lima Silva
- Richard Costa de Brito
- Enzo Damasceno Falcão
- Cristian Brandao Tavares

## Funcionalidades

### Listagem

- Consulta dos registros na nuvem, com os mais recentes primeiro.
- Exibição de nome, descrição, local, situação e data e hora do cadastro.
- Identificação de objetos perdidos e encontrados por cor, ícone e etiqueta.
- Puxar para atualizar, inclusive com a lista vazia ou com erro.
- Indicador de carregamento e mensagens em português, com botão “Tentar novamente” em caso de falha.
- Acesso ao formulário de cadastro e atualização da lista após salvar.
- Toque em um objeto para abrir a tela de detalhes.

### Cadastro

- Campos obrigatórios: nome do objeto (até 60 caracteres), descrição (até 200), local (até 60) e situação (perdido ou encontrado).
- Validação antes do envio, rejeitando campos vazios ou preenchidos apenas com espaços.
- Data e hora registradas automaticamente pelo servidor.
- Indicador de processamento, bloqueio dos campos, do botão de salvar e da saída da tela durante o envio, impedindo envios repetidos.
- Em caso de erro ou de impossibilidade de confirmar o cadastro, os dados ficam preservados e bloqueados, com as opções “Tentar novamente” e “Descartar”.
- “Tentar novamente” reutiliza o mesmo ID e os mesmos dados em uma transação: se a tentativa anterior já salvou o registro, confirma o sucesso sem duplicá-lo.
- Descartar ou sair com um envio pendente de confirmação exige confirmar o aviso de que o cadastro pode já ter sido salvo. Após descartar, atualize a lista antes de cadastrar o mesmo objeto novamente; a proteção contra duplicação vale enquanto a operação estiver preservada.
- Após o sucesso, retorno à listagem com a mensagem “Objeto cadastrado.”.

### Detalhes, edição e exclusão

Funções adicionais, não exigidas pelo trabalho:

- Tela de detalhes com nome, situação, local, descrição e data e hora do cadastro.
- **Marcar como encontrado**: botão disponível para objetos perdidos.
- **Editar**: abre o mesmo formulário do cadastro já preenchido, com as mesmas validações. A data de cadastro não é alterada.
- **Excluir**: pede confirmação antes de apagar o registro.
- As três ações usam transação no Firestore, exibem indicador durante a operação e bloqueiam a saída da tela enquanto executam. Repetir a ação não gera efeito duplicado.
- Em caso de falha, a edição oferece “Tentar novamente” e “Descartar” (com confirmação), como no cadastro; marcar como encontrado e excluir oferecem “Tentar novamente” e “Cancelar”.
- Marcar como encontrado altera somente a situação, preservando os demais dados atuais do registro, mesmo que tenham sido editados em outro aparelho.
- Ao concluir, retorno à listagem atualizada com a mensagem “Objeto atualizado.”, “Objeto marcado como encontrado.” ou “Objeto excluído.”.

A leitura consulta o servidor e exige conexão; falhas de comunicação são exibidas ao usuário. O aplicativo não possui autenticação.

## Tecnologias

Desenvolvido com Flutter 3.47.6 (Dart 3.13.5)

- Flutter no canal stable e componentes Material 3.
- `provider` com `ChangeNotifier` para gerenciamento de estado.
- `firebase_core` para inicialização do Firebase.
- `cloud_firestore` para leitura e gravação assíncronas no Firestore.
- `flutter_localizations` para a interface em português do Brasil.

## Armazenamento em nuvem

Os registros são persistidos no Firebase Cloud Firestore, no plano gratuito Spark, e compartilhados entre as instalações do aplicativo.

| Parâmetro | Valor |
| --- | --- |
| Projeto | `achados-perdidos-uespi` |
| Banco | `(default)` |
| Região | `southamerica-east1` (São Paulo) |
| Coleção | `lost_items` |

Cada documento da coleção representa um objeto:

| Campo | Tipo | Validação |
| --- | --- | --- |
| `name` | string | Obrigatório, até 60 caracteres |
| `description` | string | Obrigatório, até 200 caracteres |
| `location` | string | Obrigatório, até 60 caracteres |
| `status` | string | `lost` (perdido) ou `found` (encontrado) |
| `createdAt` | timestamp | Data e hora do servidor, com `FieldValue.serverTimestamp()` |

As regras de [firestore.rules](firestore.rules) permitem:

- leitura pública;
- criação somente com esses cinco campos válidos, textos não vazios e data e hora do servidor;
- edição somente com os campos válidos e **sem alterar a data de cadastro**;
- exclusão de registros.

Campos extras, valores inválidos e o acesso às demais coleções são bloqueados.

Como o aplicativo não tem login, qualquer pessoa pode editar ou excluir registros. Essas regras são adequadas apenas a um aplicativo demonstrativo: utilize somente dados demonstrativos, sem informações pessoais ou sensíveis.

## Configuração

A configuração de cliente do Firebase já está no repositório, em [lib/firebase_options.dart](lib/firebase_options.dart) e [android/app/google-services.json](android/app/google-services.json). Esses valores identificam o projeto e os aplicativos e não são credenciais privadas.

Não é necessário login nem conta Firebase para executar o aplicativo. Também não é necessário instalar Firebase CLI, executar `flutterfire configure` ou criar outro projeto Firebase.

Identificadores copiados de `lib/firebase_options.dart`:

| Parâmetro | Valor |
| --- | --- |
| `projectId` | `achados-perdidos-uespi` |
| `appId` Android | `1:894423709654:android:2ad66fba4d68f0ddc55677` |
| `appId` Web | `1:894423709654:web:f18e78f5f44825d2c55677` |
| `messagingSenderId` | `894423709654` |
| `apiKey` Android | `AIzaSyCgfhi2BxWaYtbv8ijXfULoK3qLJoAy314` |
| `apiKey` Web | `AIzaSyA87IiVAhURWiEtk-0o3K8uvFXSHwHfUnA` |
| `authDomain` Web | `achados-perdidos-uespi.firebaseapp.com` |
| `storageBucket` Android e Web | `achados-perdidos-uespi.firebasestorage.app` |

O pacote Android registrado é `br.uespi.achados_perdidos`.

### Para administradores do Firebase

O [firebase.json](firebase.json) define o banco, a região e o arquivo de regras; o [.firebaserc](.firebaserc) seleciona o projeto; e o [firestore.rules](firestore.rules) contém as regras de acesso. Esses arquivos são usados na administração da nuvem.

Com Firebase CLI instalado e uma conta autenticada com permissão no projeto, publique as regras a partir da raiz:

```bash
firebase deploy --only firestore:rules
```

Essa etapa é necessária apenas para administrar as regras, não para executar o aplicativo.

## Execução

### Pré-requisitos

- Flutter 3.47.6 (stable), com Dart 3.13.5; confira com `flutter --version` e mantenha essa versão.
- Git para clonar o repositório.
- Android SDK e emulador ou dispositivo Android conectado para execução no Android.
- Chrome para execução Web.
- Conexão com a internet para acessar o Firestore.

É possível utilizar Android, Web ou ambos, conforme as ferramentas instaladas. Desktop (Linux, Windows e macOS) e iOS não estão configurados.

### Clonar e instalar as dependências

```bash
git clone https://github.com/VitoEmanoel/Achados-Perdidos-Aval2.git
cd Achados-Perdidos-Aval2
flutter pub get
```

### Executar no Chrome

```bash
flutter run -d chrome
```

### Executar no Android

Inicie o emulador ou conecte um dispositivo Android com depuração USB habilitada e execute:

```bash
flutter run
```

Se houver mais de um dispositivo disponível, selecione o Android.

### Qualidade

```bash
dart format .
flutter analyze
```

### Testes

```bash
flutter test
```

Os testes cobrem o modelo, os controladores e as telas de listagem, cadastro, edição e detalhes. Utilizam um repositório simulado, sem acessar o Firestore real.

## Estrutura de pastas

```text
lib/
  main.dart                              Inicialização do Firebase e do aplicativo.
  app.dart                               Tema, localização, provedores e tela inicial.
  firebase_options.dart                  Configuração Firebase para Android e Web.
  models/
    lost_item.dart                       Modelo, rascunho, situações e limites dos campos.
  data/
    lost_item_repository.dart            Interface do repositório e acesso ao Firestore.
  state/
    lost_items_controller.dart           Estado e carregamento da listagem.
    item_form_controller.dart            Estado do cadastro e da edição: envio, nova tentativa e descarte.
    item_actions_controller.dart         Estado das ações de marcar como encontrado e excluir.
  ui/
    screens/
      item_list_screen.dart              Tela de listagem, acesso aos detalhes e ao cadastro.
      item_form_screen.dart              Formulário de cadastro e edição, validação e descarte.
      item_detail_screen.dart            Detalhes, marcar como encontrado, edição e exclusão.
    widgets/
      lost_item_card.dart                Cartão do objeto e formatação de data e hora.
      item_status_style.dart             Cores, ícones e rótulos das situações.
      status_badge.dart                  Etiqueta acessível da situação.
      scrollable_message.dart            Mensagens roláveis de carregamento, vazio e erro.
test/
  models/
    lost_item_test.dart                   Testes do modelo, situações e limites.
  state/
    lost_items_controller_test.dart       Testes de carregamento, atualização e falhas.
    item_form_controller_test.dart        Testes de envio, edição, prazo, repetição e descarte.
    item_actions_controller_test.dart     Testes de marcar como encontrado, exclusão e nova tentativa.
  ui/
    item_list_screen_test.dart            Testes da listagem e das ações de atualização.
    item_form_screen_test.dart            Testes de validação, envio e descarte no formulário.
    item_detail_screen_test.dart          Testes da tela de detalhes, edição e exclusão.
  support/
    fake_lost_item_repository.dart        Repositório simulado para os testes.
```
