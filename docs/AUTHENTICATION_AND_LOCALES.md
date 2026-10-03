# Autenticação do painel e idiomas

## Correção do resultado no visor

O teclado aceitava qualquer entrada do fluxo de elevador e mostrava SUCCESS antes
de consultar `pr_elevator:server:checkFloorAccess`. A notificação também usava
`menu.invalid_password`, ausente nas traduções anteriores.

Agora o fluxo é: digitação → VERIFICANDO → resultado do servidor. A senha incorreta
mostra SENHA INVÁLIDA no próprio visor, não libera transporte e permite tentar de
novo. A correta mostra SUCESSO por 750 ms antes de fechar e transportar. Selecionar
um andar protegido mostra SENHA e abre a etapa de autenticação sem afirmar sucesso.
Andar inexistente, andar atual e acesso negado também têm estados próprios no visor.

Durante a consulta, confirmações e digitação duplicadas são bloqueadas; cancelar
continua permitido. Cancelamento, remoção do painel e nova sessão invalidam respostas
atrasadas. Falha da consulta mostra ERRO e libera a entrada para tentar novamente.
A sincronização tardia da câmera preserva o estado atual do visor.

## Quatro idiomas

Arquivos: `locale/pt-br.lua`, `locale/en-us.lua`, `locale/es-es.lua` e
`locale/fr-fr.lua`. Todos contêm as mesmas 190 chaves, com parâmetros equivalentes.
Visor, notificações, menus, configurações, rótulos dos cartões e diagnósticos são
resolvidos pelo locale do PR Bridge. O HTML/JavaScript não define mensagens do visor.
Nomes definidos pelo administrador, identificadores técnicos, comandos e códigos
de andar são dados e permanecem inalterados.

O idioma acompanha a configuração vigente do PR Bridge (`pr_bridge:locale`), com
valores `pt-br`, `en-us`, `es-es` ou `fr-fr`. Este trabalho não altera globalmente o
idioma da base. Se alterar essa configuração, siga o procedimento do bridge para
recarregar seus consumidores; não foi implementada uma troca dinâmica de idioma.

`shared/config.lua` usa `labelKey` nos cartões padrão. Rótulos personalizados
continuam aceitos. O exemplo `install/install.lua` resolve explicitamente o locale
de `pr_elevator` e exige `@pr_bridge/init.lua` carregado no ambiente que o executar.
Para copiar esses itens para um inventário independente, mantenha a inicialização
do bridge no consumidor. O arquivo não é executado pelo manifesto do elevador.

## Verificação

- `luac55.exe -p`: sintaxe de todos os arquivos Lua do recurso.
- `dui_flow_test.lua`: teclado real com servidor simulado, senha incorreta/correta,
  repetição, exceção, cancelamento e resposta atrasada de outra sessão.
- `runtime_password_test.lua`: fluxo real de seleção do andar, consulta de senha,
  notificação traduzida e transporte somente após retorno permitido.
- `locale_test.lua`: chaves, parâmetros e referências de tradução nos quatro idiomas.
- Testes existentes: configuração JSON, providers de interação e DOM da DUI.

Teste no jogo ainda pendente: reinicie `pr_elevator`, selecione um andar protegido,
digite uma senha errada e depois a correta sem reabrir o painel. Confirme os estados
do visor, a tradução da notificação e transporte apenas na segunda tentativa.
Teste também cada idioma. Os testes locais não equivalem à aprovação no FiveM.
