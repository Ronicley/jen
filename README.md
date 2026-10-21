# jen

Aplicativo local de acompanhamento de compras de mercado, feito com Expo SDK 58, React Native, Expo Router e SQLite. Interface em português, com Manrope/Inter incluídas no bundle, sem login ou backend.

## Versão nativa SwiftUI

O projeto paralelo em [`swift/`](swift/README.md) implementa os fluxos principais em SwiftUI para iOS 17+, com build via `xtool` no Linux/WSL. O Expo continua independente; os dados não são compartilhados automaticamente.

Para instalar a versão Swift no iPhone pelo Windows/WSL, siga o [passo a passo de deploy](DEPLOY_IPHONE.md).

## Executar

```sh
npm install
npm start
```

Abra em Android/iOS com um cliente compatível com SDK 58. Se o Expo Go instalado não suportar essa versão, use um build nativo (`npx expo run:android` com Android Studio; `npx expo run:ios` em macOS/Xcode). O alvo desta primeira entrega é mobile; SQLite web exige configuração adicional de WASM e headers de isolamento e não foi validado.

## Implementado

- Orçamento, mercado opcional e uma compra em andamento por vez.
- Carrinho com edição, remoção, aviso de orçamento excedido e finalização.
- Preço por unidade, por kg (peso em gramas) ou total da embalagem.
- Dinheiro em centavos; arredondamento por item pesado; saldo sempre derivado do carrinho.
- Captura real de etiqueta pela câmera, lanterna e confirmação manual com foto de referência.
- Lista persistente com marcação e remoção de itens, acessível durante a compra.
- Histórico das compras e comparação de produtos explicitamente associados pelo usuário.
- Resumo do mês: total, quantidade de compras e média.
- Dados em `jen.db`; fotos temporárias apenas no cache, não usadas como histórico permanente.

## Limites desta etapa

**OCR não está integrado.** A câmera fotografa, mas não reconhece nome/preço. A tela explica isso, e nenhum valor é inferido ou adicionado sem confirmação. Próximo passo: validar OCR on-device com etiquetas reais e um development build nas plataformas escolhidas.

A lista ainda não é associada automaticamente aos itens do carrinho. Não há múltiplas listas, backup/restauração, gráfico de evolução, haptics ou desfazer rápido. Produtos podem ser associados na adição/edição da compra aberta; associação posterior em compras finalizadas ainda não foi implementada. Comparações por embalagem dependem da confirmação de marca e tamanho pelo usuário. Desinstalar o aplicativo pode apagar os dados.

## Verificação

Node 24 é utilizado para os testes, incluindo o SQLite embutido do Node:

```sh
npm run typecheck
npm run lint
npm test
npx expo install --check
npx expo export --platform android
```

Os testes cobrem parsing de dinheiro, quantidades, arredondamento por peso, atualização do saldo, restrições do schema e persistência SQLite. Não substituem testes em aparelho nem exercitam o bridge nativo do Expo.

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
