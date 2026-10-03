# Configurações de interação do elevador

No menu de gerenciamento, abra **Configurações do elevador**. O atalho existente
não foi alterado. O formulário usa o PR Bridge e permite escolher:

- PR Bridge Target, PR Bridge Interact ou ambos;
- respeitar paredes/obstáculos ou ignorar a verificação de visibilidade;
- afastamento à frente do painel, de 0,05 a 1 metro (padrão: 0,18 m);
- distância para interagir, de 0,5 a 5 metros (padrão: 2 m).

Preferências persistidas em `data/settings.json`. A direção frontal do modelo atual
é o eixo Y local negativo, preservando a posição/rotação salvas dos painéis. O ponto
de Interact fica à frente do prop para reduzir a obstrução pelo próprio painel.
Desativar obstáculos altera somente a disponibilidade da interação; não remove a
colisão física do prop nem ignora permissões de acesso aos andares.

## Permissão e sincronização

A consulta das configurações é pública para sincronizar clientes. Alterações são
validadas no servidor: whitelist administrativa do PR Bridge, ACE `pr_elevator.admin`
ou privilégios admin/god aceitos pelo bridge/framework. Jobs autorizados apenas a
criar elevadores pelo export não ganham permissão de configurar todo o recurso.

O servidor valida modo, booleano e limites, salva pelo serviço JSON do bridge e só
depois atualiza cache/broadcast. Falha na gravação não aplica parcialmente. Revisões
protegem contra sobrescrever outro administrador com um formulário antigo e contra
eventos fora de ordem no cliente. JSON inválido gera aviso e defaults seguros sem
sobrescrever o arquivo automaticamente.

Ao salvar, todos os clientes atualizam as preferências e recriam os registros dos
painéis. A limpeza considera os IDs realmente registrados, não o novo modo, para
remover Target e Interact antigos sem duplicar. Nenhum `exports.interact` externo,
`ox_target` ou fallback de framework participa da interação do painel: as chamadas
de registro/remoção são diretamente ao recurso PR Bridge.

`shared/config.lua` mantém defaults de inicialização; o JSON sincronizado é a fonte
autoritativa destes quatro campos. Outros parâmetros existentes (animação, atalhos,
cartões etc.) permanecem intactos. Não altera a configuração global do PR Bridge,
outros scripts, banco de elevadores, posicionamento salvo ou a correção de DUI.

## Validação

Arquivos Lua validados com luac55. `settings_test.lua` cobre persistência, cache,
permissões, limites, revisão, falha de gravação e atualização do cliente.
`interaction_provider_test.lua` cobre chamadas exclusivamente ao PR Bridge, ponto
frontal, flags de obstáculos e remoção após troca de modo. Testes da DUI continuam
passando. Aprovação visual/in-game pendente.

Reinicie somente `pr_elevator`. Abra as configurações com uma conta administradora,
troque os modos e confira que há uma única interação no painel. Teste paredes
ativadas/desativadas e reinicie novamente para confirmar a persistência.
