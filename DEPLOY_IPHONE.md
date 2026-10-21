# Deploy do jen no iPhone (SwiftUI + xtool)

Este guia instala a versão nativa que está em **`swift/`**. Não é o fluxo de build do Expo/React Native, App Store ou TestFlight.

O procedimento validado neste projeto usa:

**iPhone por USB → Apple Devices no Windows → ponte TCP para o WSL → xtool**.

Não é necessário transferir o dispositivo USB para o Linux com `usbipd`. O Apple Devices continua responsável pela conexão com o iPhone.

## 1. Pré-requisitos

### No Windows e no iPhone

- Apple Devices instalado, reconhecendo o iPhone conectado por cabo.
- iPhone desbloqueado; aceite **Confiar neste computador**, se solicitado.
- Modo de Desenvolvedor ativado em **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor**, quando disponível/solicitado pelo iOS. A ativação pode exigir reinicialização.
- Deixe o aparelho desbloqueado e o jen fechado durante a instalação.

### No WSL

- Swift, xtool e Darwin SDK configurados.
- Autenticação Apple válida no xtool.
- Ponte de conexão ao Apple Devices configurada (seção 3).

Na raiz do repositório, confira:

```bash
command -v swift
command -v xtool
swift sdk list
xtool auth status
```

Se faltar a configuração inicial:

```bash
xtool setup
```

Se precisar autenticar novamente:

```bash
xtool auth login
```

Siga as solicitações interativas. Não coloque senha Apple em scripts, comandos salvos ou arquivos do projeto.

## 2. Configuração do app

O arquivo **`swift/xtool.yml`** define:

```yaml
version: 1
bundleID: com.ronicley.jen.swift
product: Jen
infoPath: Support/Info.plist
iconPath: jen-logo.png
```

- **Bundle ID:** identidade base do app. Mantenha o mesmo para atualizar a instalação existente.
- **Produto:** determina o nome do artefato `Jen.ipa`.
- **Info.plist:** versão, nome exibido e permissão da câmera.
- **Ícone:** `swift/jen-logo.png`.

A logo interna usa uma cópia empacotada pelo SwiftPM. Se a imagem original mudou, sincronize a partir da raiz do repositório:

```bash
cp swift/jen-logo.png swift/Sources/swift/Resources/jen-logo.png
```

## 3. Conectar o WSL ao Apple Devices

### 3.1. Usar a ponte existente

No WSL, obtenha o endereço do Windows no modo NAT e configure a variável:

```bash
export WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
export USBMUXD_SOCKET_ADDRESS="${WINDOWS_HOST}:27015"
printf 'Apple Devices: %s\n' "$USBMUXD_SOCKET_ADDRESS"
```

No ambiente em que o deploy foi validado, o endereço era **`172.25.128.1:27015`**. Ele pode mudar após reiniciar o Windows/WSL; não dependa desse valor fixo.

Confira a conexão:

```bash
xtool devices --no-wait
```

Exemplo do resultado esperado:

```text
iPhone [usb]: UDID_DO_IPHONE
```

A variável precisa continuar exportada no mesmo terminal em que você executará os comandos de build/instalação.

> O cálculo de `WINDOWS_HOST` acima é para WSL em modo NAT, usado neste ambiente. Em rede espelhada ou outra configuração, use o endereço em que a ponte está realmente escutando.

### 3.2. Somente se a ponte não estiver configurada

Primeiro, com o Apple Devices aberto e o iPhone reconhecido, verifique no **PowerShell do Windows**:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 27015
netsh interface portproxy show v4tov4
```

Neste ambiente, o serviço Apple escuta em `127.0.0.1:27015` e uma regra encaminha a interface do Windows acessível pelo WSL para essa porta.

Se o serviço Apple **não** estiver escutando, resolva a conexão no Apple Devices antes de criar o encaminhamento.

Para configurar a ponte, descubra no WSL:

```bash
ip route show default
hostname -I
```

Depois, no **PowerShell como administrador**, substitua os endereços abaixo pelos valores atuais. `WindowsHost` é o gateway visto no WSL; `WslIP` é o IPv4 do WSL:

```powershell
$WindowsHost = "<IP do Windows acessivel pelo WSL>"
$WslIP = "<IPv4 do WSL>"

netsh interface portproxy add v4tov4 listenaddress=$WindowsHost listenport=27015 connectaddress=127.0.0.1 connectport=27015

New-NetFirewallRule -DisplayName "jen - Apple Devices para WSL" -Direction Inbound -Action Allow -Protocol TCP -LocalAddress $WindowsHost -LocalPort 27015 -RemoteAddress $WslIP -Profile Any
```

**Segurança:** a porta dá acesso à comunicação com dispositivos Apple. Restrinja o firewall ao IP do WSL e o endereço de escuta à interface necessária. Não use `0.0.0.0` nem libere a porta para toda a rede.

Se os IPs mudarem, atualize as regras. Para remover uma configuração antiga, no PowerShell como administrador, usando o endereço de escuta antigo:

```powershell
netsh interface portproxy delete v4tov4 listenaddress=<IP antigo> listenport=27015
Remove-NetFirewallRule -DisplayName "jen - Apple Devices para WSL"
```

Após configurar, volte ao WSL e repita a seção 3.1.

## 4. Validar antes do deploy

Execute na **raiz do repositório**:

```bash
bash swift/scripts/test.sh
```

Esse comando testa regras de compra, cálculos, interpretação de cupons, descontos, duplicidade e compatibilidade com dados antigos. Não substitui a validação da interface, câmera e OCR com fotos reais no aparelho.

Se também quiser validar o projeto Expo, independentemente do app Swift:

```bash
npm run typecheck
npm run lint
```

No ambiente atual, o typecheck passa, mas o lint do Expo encontra uma dependência nativa ausente do `unrs-resolver`. Esse problema é separado do build Swift.

## 5. Compilar, assinar e instalar

### Fluxo usado com sucesso para atualizar este iPhone

Na **raiz do repositório**, com a variável de conexão configurada:

```bash
export WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
export USBMUXD_SOCKET_ADDRESS="${WINDOWS_HOST}:27015"

xtool devices --no-wait
export IPHONE_UDID="COLE_O_UDID_RETORNADO_ACIMA"

cd swift
xtool dev build --ipa --sign
xtool install --udid "$IPHONE_UDID" xtool/Jen.ipa
```

Substitua `COLE_O_UDID_RETORNADO_ACIMA` pelo identificador real retornado por `xtool devices --no-wait`. O identificador do aparelho não deve ser publicado no repositório.

O arquivo gerado fica em:

```text
swift/xtool/Jen.ipa
```

O instalador pode provisionar e assinar novamente o pacote. Aguarde todas as etapas, incluindo **Verifying**, até aparecer:

```text
Successfully installed!
```

**Chegar a 100% em Installing não confirma a instalação:** a verificação ainda pode falhar.

### Importante: mantenha o mesmo fluxo de assinatura

Neste ambiente, o xtool acrescenta prefixos à identidade durante a assinatura. O fluxo **build com `--sign` → install** acima foi o utilizado para instalar e atualizar o jen existente.

Uma tentativa de **build sem assinatura → install** foi tratada como outro app e esbarrou no limite de apps da conta Apple gratuita. Portanto, para atualizar esta instalação, mantenha o mesmo Bundle ID, conta Apple e sequência de comandos validada.

Não desinstale o app apenas para contornar esse erro: isso pode apagar os dados locais. Se mudar de versão do xtool ou de configuração de assinatura, confira a identidade gerada antes de substituir o fluxo.

## 6. Abrir e conferir no iPhone

Abra o **jen** pelo ícone na tela inicial.

Se o iOS solicitar confiança no desenvolvedor, confira **Ajustes → Geral → VPN e Gerenciamento de Dispositivo**, quando essa opção estiver disponível, e autorize o perfil usado na instalação. Se solicitar Modo de Desenvolvedor, ative-o e siga o processo do iOS.

Confira pelo menos:

1. A logo aparece no ícone e dentro do app.
2. Compras e lista anteriores continuam disponíveis após a atualização.
3. Criar/editar itens e tocar e segurar para abrir ações.
4. Ler uma etiqueta e conferir nome/preço antes de adicionar.
5. Histórico → Importar cupom → revisar produtos e total → salvar.
6. Fechar/reabrir o app e conferir persistência.

O lançamento automático pelo `xtool launch` não foi confiável neste ambiente, devido à identidade efetiva após assinatura. A instalação foi confirmada pelo xtool; a abertura manual pelo ícone é o procedimento recomendado aqui.

## 7. Problemas comuns

### O xtool não encontra o iPhone

- Confira se o Apple Devices reconhece o aparelho no Windows.
- Desbloqueie o iPhone e aceite a confiança no computador.
- Verifique se `USBMUXD_SOCKET_ADDRESS` está exportada **no terminal atual**:

```bash
printf '%s\n' "$USBMUXD_SOCKET_ADDRESS"
xtool devices --no-wait
```

- Confira a porta, o encaminhamento e o firewall no Windows.
- Se reiniciou o WSL/Windows, confira se os IPs mudaram.

### `Device busy` ao executar `usbipd attach`

Esse erro ocorreu porque o dispositivo estava sendo usado pelo Windows. **Este guia não usa `usbipd attach`**: mantenha a conexão no Apple Devices e use a ponte TCP. Não force a transferência USB quando estiver usando esse fluxo.

### `ApplicationVerificationFailed`: limite de apps gratuitos

O aparelho pode ter atingido o limite de apps assinados com perfil gratuito. Confira primeiro se está instalando uma atualização com a **mesma identidade e fluxo de assinatura**, em vez de criar outra instalação.

Não apague o jen ou outros apps automaticamente. Se realmente precisar liberar espaço nesse limite, escolha conscientemente um app que pode ser removido e proteja os dados antes. Contas gratuitas também podem exigir renovação periódica da assinatura.

### Instalação para em 100% e não confirma

- Mantenha o iPhone desbloqueado, com o jen fechado.
- Confira avisos de confiança ou Modo de Desenvolvedor na tela.
- Aguarde a etapa de verificação; ela pode demorar.
- Se o comando encerrar por timeout, não considere a atualização concluída. Tente instalar novamente e procure `Successfully installed!`.

### Erro de autenticação ou provisionamento

```bash
xtool auth status
xtool auth login
```

Confira também a conexão com a internet necessária para autenticação/provisionamento e se a conta pode assinar para o dispositivo.

### A logo mudou, mas a imagem interna não

Sincronize a cópia do recurso, compile novamente e instale:

```bash
# Na raiz do repositório:
cp swift/jen-logo.png swift/Sources/swift/Resources/jen-logo.png
# Use IPHONE_UDID e USBMUXD_SOCKET_ADDRESS configurados nas etapas anteriores.
cd swift
xtool dev build --ipa --sign
xtool install --udid "$IPHONE_UDID" xtool/Jen.ipa
```

## 8. Dados e cuidados

- O app guarda dados em `Documents/jen-swift-v1.json` no próprio iPhone.
- Atualizações com a mesma identidade normalmente preservam o armazenamento. **Desinstalar pode apagá-lo.**
- Não há uma função de backup/exportação implementada. Evite testes de remoção em uma instalação com dados importantes.
- O `.ipa` é um artefato de build, não um backup das compras.
- Não versionar credenciais, certificados, tokens ou perfis de assinatura.
- Esta instalação é para desenvolvimento/testes; não equivale à distribuição pela App Store.
