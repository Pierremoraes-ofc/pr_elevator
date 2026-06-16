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
