# Análise do display do elevador

Status: correção de inicialização validada em testes; confirmação visual no FiveM pendente.

## Fluxo

1. Menus de criação/reposicionamento usam gizmo e salvam modelo/coordenadas/rotação
   em `interact_coords`, por meio dos eventos do servidor.
2. `client/main.lua` consulta elevadores/andares e cria os painéis com seus targets.
3. A interação abre `OpenKeypadEntity` com o texto `ANDAR`; o teclado envia os
   dígitos e confirma o andar escolhido.
4. `server:checkFloorAccess` confere os requisitos. Se houver senha, o cliente abre
   o mesmo teclado com o texto traduzido de senha; depois executa o transporte.
5. `client/dui.lua` administra os textos, botões e câmera. O PR Bridge cria a página
   DUI, envia as mensagens e substitui a textura. `ui/script.js` escreve o texto
   dentro de `.display`. Banco/cache não são responsáveis por desenhar esse texto.

## Falha reproduzida

A mesma página HTML era usada para a NUI de tela e a textura DUI. Ao terminar de
carregar, seu JavaScript ocultava o teclado incondicionalmente, inclusive se já
tivesse recebido a mensagem para mostrá-lo. Só o texto era preservado. As folhas
de estilo/fontes externas podiam atrasar o carregamento além das tentativas fixas
de sincronização do Lua. Isso explica um caminho de painel invisível sem interromper
os cliques, a validação da senha nem o transporte.

## Correção aplicada

- DUI usa `?dui=1`; o teclado da textura começa visível, mas a NUI de tela fica oculta.
- Estado de visibilidade e último texto sobrevivem à inicialização do documento.
- Quando a página fica pronta, avisa o Lua, que reenvia o estado pelo PR Bridge.
- Nenhuma fonte ou biblioteca externa é necessária para mostrar o display.
- Textos longos ajustam o tamanho da fonte para caber no visor.
- `/prelevator_dui_status` mostra no F8 a instância, prontidão da página, URL e
  textura configurada, sem registrar senha ou dígitos.

Não foram modificados acessos, permissões, senhas, transporte, posições salvas,
banco, cache, PR Bridge ou XT Prison. O mapeamento existente da textura foi mantido;
se o display continuar ausente, será necessário verificar esse mapeamento no jogo.

## Validação e teste no servidor

`tests/dui_page_test.cjs`: reproduz o erro original e verifica inicialização,
mensagens antecipadas, visor, separação DUI/NUI e aviso de prontidão.
`tests/dui_flow_test.lua`: executa o módulo Lua real com dependências simuladas,
conferindo mensagens do andar, dígitos, correção, confirmação, senha e reset.
Lua validado com `E:\[BASE-DE-CONHECIMENTO]\LUAC\luac55.exe` e testes executados
com `lua55.exe`; JavaScript validado e testado com Node.

Reinicie somente `pr_elevator`. Abra um painel e confira `ANDAR`, os dígitos e um
andar que peça senha. Se não aparecer, envie uma imagem e a saída de
`prelevator_dui_status` no F8. Testes simulados não substituem essa aprovação visual.

## Reteste negativo e isolamento da falha

O usuário confirmou que o visor continua sem texto. A imagem aparenta manter a
textura original; a causa em execução ainda não está confirmada. O diagnóstico
agora mostra também o modelo aberto, disponibilidade nativa e textura runtime.
Com o painel aberto, execute `prelevator_dui_preview` no F8: a mesma textura será
desenhada pelo PR Bridge à esquerda durante dez segundos e removida automaticamente.
Envie a imagem dessa prévia e as duas linhas de `prelevator_dui_status`. Uma prévia
correta com painel incorreto isola o problema na aplicação ao modelo; uma prévia
vazia exige investigar primeiro página/CEF/textura runtime. Nenhuma senha ou
valor digitado é registrado no diagnóstico. Não declarar aprovado antes do reteste.
