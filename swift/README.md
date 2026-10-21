# jen — versão nativa SwiftUI

Projeto paralelo ao Expo, para iOS 17+, sem dependências externas. O app original em `../src/` permanece intacto.

## Build com xtool (Linux/WSL ou macOS)

Requer Swift e Darwin SDK configurados no xtool (`xtool setup`).

```sh
cd swift
xtool dev build --ipa
# Resultado: xtool/Jen.ipa (sem assinatura para instalação)

# Build assinado, com a conta Apple configurada no xtool:
xtool dev build --ipa --sign
xtool devices --no-wait
xtool install xtool/Jen.ipa
# Ou build + assinatura + execução pelo fluxo do xtool:
xtool dev
```

O bundle ID inicial é `com.ronicley.jen.swift`, em `xtool.yml`. Ajuste-o se necessário para sua conta Apple. O iPhone precisa estar acessível ao ambiente do xtool, pareado e com o Modo de Desenvolvedor ativado; conectar ao Windows não garante acesso pelo WSL. Uma compilação sem assinatura não é suficiente para instalar no aparelho.

## Funcionalidades

- Início com saldo da compra ativa, resumo mensal e última compra.
- Orçamento em centavos e apenas uma compra em andamento.
- Carrinho com inclusão, edição, remoção com confirmação e finalização.
- Unidade, peso em gramas com preço/kg e total por embalagem.
- Lista persistente com marcação, edição de nome e exclusão com confirmação. Toque para marcar; toque e segure para Editar item / Apagar item. Renomear preserva a marcação.
- Itens da compra (digitados ou confirmados pelo OCR) têm o mesmo menu de toque e segurar, tanto no carrinho quanto nas compras finalizadas. Toque simples continua abrindo a edição; exclusão pede confirmação e recalcula os totais.
- Produtos explicitamente associados, comparação com a compra anterior e últimos cinco registros de preço.
- Histórico de compras com detalhes expansíveis. Toque e segure uma compra finalizada para editar ou apagar; as mesmas ações estão disponíveis para VoiceOver.
- Edição de mercado, orçamento, data e itens sem reabrir a compra ou interferir na compra ativa. Dados gerais têm botão Salvar; cada item é salvo em seu próprio formulário. Uma compra finalizada mantém pelo menos um item.
- Exclusão com confirmação remove a compra e seus itens, recalculando resumo mensal e preços; preserva cadastros de produtos e outras compras.
- Câmera nativa com OCR local via Apple Vision: sugestões de nome, preços, preço/kg, total e peso explícito. Um único preço preenche um campo vazio; múltiplos preços exigem escolha. Texto completo disponível para conferência. Sem servidor; foto descartada ao sair do formulário.
- Sugestões sempre editáveis e confirmação obrigatória antes de adicionar. O OCR pode falhar com reflexos, etiquetas inclinadas, dígitos separados ou layouts complexos. Condições promocionais não são interpretadas automaticamente; tamanho da embalagem não é tratado como peso comprado.
- Identidade nativa com logo no cabeçalho das telas, azul-marinho e turquesa da marca, cartões arredondados e fonte de sistema.
- Atalhos visuais Ler etiqueta / Digitar no carrinho, seletor com ícones de unidade/peso/embalagem e menus visíveis “⋯” para editar/apagar itens e compras, além do toque longo.
- Rótulos curtos junto aos ícones, áreas de ação de pelo menos 44 pt e descrições para VoiceOver. Informações importantes sobre OCR e exclusão continuam explícitas. Validação visual com Dynamic Type e VoiceOver no aparelho ainda necessária.

## Importar uma compra por cupom fiscal

No Histórico, toque em **Importar cupom**:

1. Fotografe ou selecione imagens na galeria (até 10 por importação). Use trechos legíveis para cupons longos; ordene as fotos com as setas e remova/refaça quando necessário.
2. Toque em **Ler e revisar**. Apple Vision reconhece o texto localmente; o parser reconstrói produtos de formatos comuns de cupom brasileiro.
3. Confira mercado/data, nomes, quantidades, unidades, preços, total de cada produto e descontos. O menu de cada item permite revisar/apagar; também é possível adicionar um item não reconhecido. Fotos podem ser ampliadas e o texto original fica disponível durante a revisão.
4. Revise individualmente itens com avisos (baixa confiança, falta de informação, possível sobreposição ou quantidade × preço divergente). Produtos iguais não são excluídos automaticamente.
5. Ajuste descontos/acréscimos gerais e o total final. **Só é possível salvar quando a soma líquida dos itens − desconto geral + acréscimo geral conferir exatamente com o total e houver confirmação explícita.**

A compra entra no histórico como finalizada e sem orçamento obrigatório; não interfere na compra ativa. Os valores impressos por item são preservados, inclusive diferenças de arredondamento e descontos integrais. Descontos por item já entram no total líquido e não devem ser repetidos como desconto geral. Dinheiro recebido, troco e tributos informativos não são contabilizados como produtos ou ajustes.

Se só o total de um item estiver legível, escolha explicitamente **Registrar somente o total do item**, sem inventar quantidade/preço unitário. As quantidades de unidades não inteiras (como litros) são preservadas no detalhe fiscal; KG/G são convertidos para gramas inteiras. Preços de até quatro casas decimais ficam preservados no detalhe original, com representação em centavos arredondados para o modelo de preço; o total fiscal continua sendo o valor cobrado.

A chave fiscal opcional (44 dígitos) impede repetir um cupom já importado. Mesmo mercado/dia/total gera um aviso que pode ser confirmado para outra compra legítima. Nada é associado automaticamente a cadastros de produtos. Uma gravação atômica salva a compra e todos os itens juntos, após validação.

**Privacidade:** fotos e texto bruto são temporários e descartados ao sair/salvar. Só dados estruturados confirmados e, opcionalmente, a chave fiscal ficam no JSON local. Não há consulta SEFAZ, QR Code, PDF ou envio de imagens a um servidor.

**Limites:** o parser é heurístico e não reconhece todos os layouts fiscais. Informações podem faltar, especialmente em cupons amassados, fotos inclinadas, colunas desalinhadas, descontos ambíguos e produtos cortados entre imagens. Confira cada linha e use a edição manual. Cupons cancelados/devoluções, valores negativos e compras de total zero não são suportados. A precisão do Vision em cupons reais e o fluxo completo em aparelho ainda precisam de validação.

## Identidade visual

A imagem original é `jen-logo.png` na raiz deste projeto Swift, usada como ícone via `xtool.yml`. A cópia `Sources/swift/Resources/jen-logo.png` é empacotada pelo SwiftPM para os cabeçalhos internos (`Bundle.module`). Ao substituir a imagem original, sincronize a cópia antes do build:

```sh
cp jen-logo.png Sources/swift/Resources/jen-logo.png
```

Os componentes de identidade, atalhos e seletor de venda ficam em `Sources/swift/BrandComponents.swift`; a paleta está em `Theme`, em `ContentView.swift`.

## Dados

Persistência em `Documents/jen-swift-v1.json`, usando `Codable`, gravação atômica e proteção de arquivo. A interface só publica alterações depois da gravação bem-sucedida. Falhas na leitura bloqueiam alterações, sem substituir silenciosamente dados existentes.

**Não há importação automática do `jen.db` do Expo.** Esta versão usa outro bundle ID e armazenamento independente. Não há exportação/importação, sincronização ou migração SQLite nesta entrega. Desinstalar o app pode apagar seus dados.

## Verificação

Build iOS e testes das regras podem ser executados no Linux:

```sh
# A partir de swift/:
bash scripts/test.sh
xtool dev build --ipa
```

Os testes verificam centavos, rejeição de entradas ambíguas, quantidades, preços por peso/unidade/embalagem, arredondamento, serialização e extração de etiquetas (nome, múltiplos preços, preço/kg versus total, peso, datas e percentuais). A suíte de cupons também cobre produtos em múltiplas linhas, sobreposição de fotos, descontos gerais/por item, totais divergentes, precisão fiscal, duplicidade, serialização e compatibilidade com JSON antigo. Os testes usam texto sintético, não fotos reais; não cobrem a precisão do reconhecimento Vision, interface, assinatura Apple ou câmera em hardware.

### Roteiro em aparelho

1. Criar orçamento de R$ 300,00, sair do app e conferir persistência.
2. Adicionar 3 leites de R$ 5,49 e 650 g de tomate de R$ 7,99/kg: total R$ 21,66, saldo R$ 278,34.
3. Editar/remover itens, exceder orçamento e conferir saldo.
4. Negar câmera e digitar manualmente; depois permitir e capturar foto. Conferir OCR em etiquetas simples, promoções com dois preços, peso/kg e total, fotos giradas e com reflexos. Garantir que nada entre no carrinho sem confirmação.
5. Cadastrar/associar produto, finalizar duas compras e comparar preços.
6. Marcar/remover itens da lista e verificar após reabrir.
7. No histórico, tocar e segurar uma compra: editar mercado/orçamento/data e salvar; editar, adicionar e remover itens. Conferir totais, preços e persistência ao reabrir.
8. Apagar uma compra: cancelar primeiro, depois confirmar. Conferir que seus itens sumiram do histórico e que outras compras, lista e cadastros continuam intactos.
9. Importar um cupom simples e outro com peso/descontos: conferir produtos, totais e data; corrigir um item, apagar uma repetição e adicionar um produto ausente. Verificar que uma divergência bloqueia o botão Salvar.
10. Testar câmera negada, galeria, imagens deitadas, iCloud, foto ilegível, ordem de várias fotos e ampliação. Cancelar durante a leitura e durante a revisão: nenhum registro deve ser criado.
11. Importar enquanto há compra ativa: a compra ativa deve continuar intacta. Fechar/reabrir depois de confirmar; conferir histórico e resumo mensal, descontos e total original.
12. Tentar importar a mesma chave novamente (bloqueado) e compra semelhante sem chave (confirmação). Editar/apagar uma compra importada e conferir recálculo dos totais.
13. Conferir VoiceOver, fontes ampliadas, teclado, navegação e confirmação de finalização.

## Arquivos

- `Sources/swift/Models.swift`: modelos Codable, validação e cálculos.
- `Sources/swift/Store.swift`: estado e persistência local.
- `Sources/swift/ContentView.swift`: componentes, início, nova compra e carrinho.
- `Sources/swift/ItemForm.swift`: formulário, revisão do OCR e câmera UIKit.
- `Sources/swift/LabelRecognizer.swift`: reconhecimento local Apple Vision fora da thread da interface.
- `Sources/swift/LabelParser.swift`: extração conservadora de nomes, preços e peso.
- `Sources/swift/HistoryView.swift`: lista, histórico e menu contextual de compras.
- `Sources/swift/EditFinishedTripView.swift`: edição de compras finalizadas.
- `Sources/swift/PurchaseItemRow.swift`: linha de produto reutilizável, edição e menu contextual com exclusão confirmada.
- `Support/Info.plist`: metadados e descrição de uso da câmera.
- `Sources/swift/ReceiptModels.swift`: rascunhos fiscais, valores decimais, reconciliação, duplicidade e importação atômica no snapshot.
- `Sources/swift/ReceiptParser.swift`: interpretação conservadora de cupons.
- `Sources/swift/ReceiptImportView.swift`: câmera/galeria, ordenação de imagens e processamento cancelável.
- `Sources/swift/ReceiptReviewView.swift`: confirmação e edição de produtos antes de salvar.
- `Sources/swift/ReceiptPhotoPreview.swift`: consulta/ampliação das fotos temporárias.
- `Tests/DomainChecks.swift` e `Tests/ReceiptChecks.swift`: verificações independentes de SwiftUI.
- `scripts/test.sh`: compila e executa as duas suítes no Linux.
