PR = {}


-------------------------------------------------------------------
-- NOTIFY POSITION SETTINGS
-------------------------------------------------------------------
PR.notifyPosition = 'center-left'

-------------------------------------------------------------------
-- KEYBINDS SETTINGS
-------------------------------------------------------------------
PR.keyBinds = {
    'ALT', '7'
}

-------------------------------------------------------------------
-- KEYCARD ITEM SETTINGS
-------------------------------------------------------------------
PR.keycardItem = 'elevator_card'
PR.InventoryImagePath = 'nui://ox_inventory/web/images/%s.png'

PR.ItemList = {
    {
        item = 'key_card_ilegal',
        label = 'Cartao Ilegal'
    },
    {
        item = 'key_card_security',
        label = 'Cartao de Seguranca'
    },
    {
        item = 'key_card_gold',
        label = 'Cartao Vip'
    }
}

-------------------------------------------------------------------
-- ELEVATOR RUNTIME SETTINGS
-------------------------------------------------------------------
PR.elevatorWaitTime = 3000

-------------------------------------------------------------------
-- MARKER SETTINGS
-------------------------------------------------------------------
PR.Marker = {
    DrawDistance = 12.0,       -- Distância máxima (em unidades) que o marcador é desenhado
    Type = 2,                  -- Tipo do marcador (2 é um tipo comum, ajuste conforme necessário)
    Scale = vector3(0.3, 0.3, 0.2), -- Marker scale dimensions
    Color = { r = 255, g = 255, b = 255, a = 200 }  -- RGBA color of the marker
}


PR.Target = 'ox_target'         -- ox_target, interact, or both

PR.KeypadInteractDistance = 2.0

-- Offset local do ponto do interact no prop DUI.
-- y = frente/trás do prop, x = lateral, z = altura.
-- No ch_prop_casino_keypad_01, a frente fica no y negativo local.
PR.KeypadInteractOffset = vector3(0.0, -0.08, 0.03)

PR.KeypadInteractionAnimation = {
    dict = 'mp_common',
    clip = 'givetake1_a',
    duration = 900,
    flags = 49
}

PR.ExportCreatorMenu = {
    enabled = true,
    -- Se jobs/gangs estiver vazio, qualquer player pode abrir pelo export.
    -- Exemplo: jobs = { realestate = 2, realtor = 0 }
    jobs = {},
    gangs = {}
}
--[[


Elevador

Acessos:
    - Emprego/Gang - Player ID
    - Emprego/Gang + Cartao
    - Emprego/Gang + Senha
    - Cartao
    - Senha

Modos de chamada: (aqui usa o front-end para chamada)
    - Solo
    - e puxar proximos

Tipos de elevador:
    - Player
    - Veiculo
    - Ambos





]]
