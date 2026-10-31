# jen

Aplicativo local de acompanhamento de compras de mercado, feito com Expo SDK 58, React Native, Expo Router e SQLite. Interface em português, com Manrope/Inter incluídas no bundle, sem login ou backend.

## Versão nativa SwiftUI

O projeto paralelo em [`swift/`](swift/README.md) implementa os fluxos em SwiftUI para iOS 17+, com build via `xtool` no Linux/WSL. Seus recursos de compras, OCR e cupons foram portados para a base Expo/Android. O código Swift permanece independente; os dados não são compartilhados automaticamente.

Para instalar a versão Swift no iPhone pelo Windows/WSL, siga o [passo a passo de deploy](DEPLOY_IPHONE.md).

## Executar

```sh
npm install
npm start
```

Use o APK ou um development build compatível com SDK 58. OCR nativo usa módulo local e **não funciona no Expo Go**; nesse cliente, a entrada manual continua disponível.

### Web e PWA

`npm run web` inicia a versão web em desenvolvimento. Para gerar o PWA estático, use `npm run build:web`; os arquivos resultantes ficam em `dist/`. A primeira visita precisa de conexão para instalar o cache. O build inclui o mecanismo e o modelo de OCR em português, processados localmente; a precisão pode ser diferente do OCR nativo. Revise os resultados.

O servidor precisa responder com `Cross-Origin-Opener-Policy: same-origin` e `Cross-Origin-Embedder-Policy: require-corp` em todas as páginas e arquivos. `public/_headers` fornece esses cabeçalhos para serviços que suportam esse formato; outros servidores precisam ser configurados separadamente. Câmera e instalação exigem HTTPS ou localhost. O banco web é local ao navegador e não sincroniza com instalações nativas ou outros dispositivos. Limpar dados do navegador pode apagar as compras; não há backup automático.

## APK Android

O perfil `preview` em `eas.json` produz APK instalável, com JavaScript e fontes incluídos, sem precisar manter Metro aberto:

```sh
npx eas-cli@latest build --platform android --profile preview
```

Projeto EAS: https://expo.dev/accounts/ronicley/projects/jen. Identificador Android: `com.ronicley.jen`.

A assinatura usa `credentials.json` e `.credentials/jen-android.jks`, locais e ignorados pelo Git. **Guarde uma cópia segura dos dois arquivos.** Sem a mesma chave não é possível atualizar uma instalação existente. Nunca publique esses arquivos nem suas senhas. Para outra máquina, restaure-os de seu backup antes do build. Não há publicação na Play Store nem EAS Update configurado.

## Implementado

- Orçamento, mercado opcional e uma compra em andamento por vez.
- Carrinho com edição, remoção, aviso de orçamento excedido e finalização.
- Preço por unidade, por kg (peso em gramas) ou total da embalagem.
- Dinheiro em centavos; arredondamento por item pesado; saldo sempre derivado do carrinho.
- Captura de etiqueta, lanterna, OCR local e escolha explícita de sugestões de nome/preço/peso. Múltiplos preços e promoções precisam de conferência.
- Lista persistente com marcação e remoção de itens, acessível durante a compra.
- Histórico das compras e comparação de produtos explicitamente associados pelo usuário.
- Resumo do mês: total, quantidade de compras e média.
- Dados em `jen.db`; fotos temporárias apenas no cache, não usadas como histórico permanente.
- Edição de nome na lista preservando marcação; menus visíveis e toque longo para editar/apagar, com confirmação de exclusão.
- Edição de mercado, orçamento, data e itens em compras finalizadas, sem reabri-las nem alterar a compra ativa; pelo menos um item é mantido.
- Exclusão de compras finalizadas com confirmação; produtos cadastrados, lista e outras compras são preservados.
- Identidade do Swift: logo original, azul-marinho e turquesa, com componentes Expo existentes.

### Importar cupom

No Histórico, toque em **Importar cupom**. Fotografe ou selecione até 10 fotos, ordene e remova/refaça trechos, depois toque em **Ler e revisar**. Fotos podem ser ampliadas; texto reconhecido fica disponível durante a revisão. Cada produto permite corrigir nome, quantidade, unidade, preço original (até quatro casas), valor bruto e desconto, ou escolher explicitamente registrar apenas seu total. É possível apagar repetições e adicionar produtos não reconhecidos.

Todos os itens precisam de confirmação individual. O salvamento exige total exato: soma líquida dos itens − desconto geral + acréscimo geral = total final. Descontos por item não devem ser repetidos como desconto geral. Quantidades fracionadas e preços originais ficam preservados no detalhe fiscal; o total impresso prevalece sobre arredondamentos de preço unitário. Pagamentos, troco e tributos não são produtos.

A compra entra finalizada, sem solicitar orçamento e sem alterar a compra ativa. Internamente, a tabela legada mantém um orçamento técnico igual ao total inicial; esse campo não é apresentado como orçamento de cupom. A chave opcional de 44 dígitos impede duplicação; mercado/dia/total iguais pedem confirmação de outra compra legítima. Itens importados não são associados automaticamente a cadastros. Compra e itens são gravados juntos em transação; uma falha reverte toda a operação. Para alterar itens fiscais depois, use **Revisar todos os itens fiscais**.

OCR Android usa ML Kit com modelo latino incluído no APK; o módulo iOS usa Apple Vision. Imagens são processadas no aparelho. Fotos ficam no cache temporário do aplicativo, sujeito à limpeza do sistema; não são salvas no histórico. Texto bruto fica somente na memória da tela. Não há envio de imagens, consulta SEFAZ, QR Code ou PDF.

## Limites desta etapa

**OCR e parser são sugestões, não uma validação fiscal.** Reflexos, rotação, colunas desalinhadas e trechos cortados podem gerar erros. Confira nomes, valores, descontos e repetições; edite manualmente quando necessário. Cupons cancelados/devoluções, valores negativos e compras com total zero não são suportados. Promoções não são interpretadas automaticamente. O peso da embalagem não é tratado como peso comprado.

A lista ainda não é associada automaticamente aos itens do carrinho. Não há múltiplas listas, backup/restauração, gráfico de evolução, haptics ou desfazer rápido. Produtos manuais podem ser associados na adição/edição, inclusive em compras finalizadas. Comparações por embalagem dependem da confirmação de marca e tamanho pelo usuário. **Não há migração automática do JSON do Swift para o Android.** Desinstalar o aplicativo pode apagar os dados.

## Verificação

Node 24 é utilizado para os testes, incluindo o SQLite embutido do Node:

```sh
npm run typecheck
npm run lint
npm test
npx expo install --check
npx expo export --platform android
```

Os testes cobrem dinheiro, peso, saldo, OCR textual, parser fiscal, precisão decimal, descontos, reconciliação, duplicidade, atualização aditiva de banco v1, edição/exclusão de histórico, renomeação da lista e rollback de falha durante importação. Operações de produção são exercitadas com adaptador SQLite do Node; isso não valida o bridge nativo do Expo, câmera, OCR em fotos reais ou acessibilidade em aparelho.

### Roteiro em aparelho

1. Criar compra de R$ 300,00. Fechar/reabrir e verificar a compra.
2. Adicionar 3 leites de R$ 5,49 e 650 g de tomate a R$ 7,99/kg: total R$ 21,66 e saldo R$ 278,34.
3. Editar quantidade, remover item e verificar recálculo; adicionar valor acima do orçamento e verificar aviso.
4. Negar câmera e usar entrada manual; permitir câmera, capturar e confirmar preço sem débito antecipado.
5. Criar produto identificado, finalizar compra, repetir em outra compra e conferir histórico.
6. Adicionar e marcar itens da lista, fechar/reabrir e verificar persistência.
7. Testar teclado, fontes ampliadas, safe areas e botão voltar em Android/iOS.

## Organização

- `src/app/`: rotas e telas.
- `src/components/design.tsx`: tokens e componentes visuais.
- `src/domain/shopping.ts`: cálculos e validação de entradas.
- `src/data/database.ts`: schema e operações SQLite parametrizadas.
- `src/data/store.tsx`: carregamento e atualização da UI após persistência.
- `src/domain/receipt.ts`: extração de etiquetas/cupons e reconciliação fiscal.
- `src/app/receipt.tsx`: captura/galeria, revisão, fotos e importação.
- `src/app/trip.tsx`: edição e exclusão de compras finalizadas.
- `modules/jen-ocr/`: módulo local Expo, ML Kit Android e Vision iOS.
