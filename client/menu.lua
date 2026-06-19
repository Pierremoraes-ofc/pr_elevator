-- criaçao do menu de elevadores e andares
local lang = pr_lib.locale()

print('idioma setado: ', lang:locale())
--  verificações importantes ao iniciar o script.
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pr_lib.debug("info", lang("debug.onResourceStart"))
    pr_lib.debug("info", lang("debug.onResourceStarted"))
end)

--  Sistema de notificaçao.
function notify(title, description, notifyType)
    pr_lib.debug("info", lang("debug.notify_client", { title = title or "N/A", description = description or "N/A", type = notifyType or "inform" }))

    pr_lib.notifications.Notify({
        title = title,
        description = description,
        type = notifyType or "inform",
        duration = 5000,
        position = PR.notifyPosition
    })
end

RegisterNetEvent('pr_elevator:client:notify', function(title, description, notifyType)
    notify(title, description, notifyType)
end)

-- Declarações locais para navegação do menu
local OpenManageMenu
local OpenElevatorListMenu
local OpenElevatorControlMenu
local OpenFloorListMenu
local OpenFloorControlMenu
local CreateElevatorMenu
local OpenElevatorEditInputDialog
local CreateFloorMenu
local CreateItemMenu
local OpenFloorDetailsInputDialog
local OpenFloorEditInputDialog
local OpenFloorDuiPlacementEditor

local DUI_KEYPAD_MODEL = joaat('ch_prop_casino_keypad_01')
local DUI_KEYPAD_MODEL_NAME = 'ch_prop_casino_keypad_01'

local function buildFloorNameOptions()
    local options = {}

    for i = 10, 1, -1 do
        local value = ('S%s'):format(i)
        options[#options + 1] = {
            value = value,
            label = value
        }
    end

    options[#options + 1] = {
        value = 'T',
        label = 'T'
    }

    for i = 1, 50 do
        local value = tostring(i)
        options[#options + 1] = {
            value = value,
            label = value
        }
    end

    return options
end

local function normalizeEmpty(value)
    if value == nil or value == '' or value == 'none' then return nil end
    return value
end

local function buildAccessTypeOptions()
    return {
        { value = 'public', label = lang('menu.form_type_public') },
        { value = 'job', label = lang('menu.form_type_job') },
        { value = 'gang', label = lang('menu.form_type_gang') },
        { value = 'citizenid', label = lang('menu.form_type_citizenid') },
        { value = 'password', label = lang('menu.form_type_password') },
        { value = 'keycard', label = lang('menu.form_type_keycard') },
        { value = 'job_citizenid', label = lang('menu.form_type_job_citizenid') or 'Emprego/Gang + Player ID' },
        { value = 'job_keycard', label = lang('menu.form_type_job_keycard') },
        { value = 'job_password', label = lang('menu.form_type_job_password') },
    }
end

local function buildJobOptions(serverJobs)
    local options = {
        { value = 'none', label = 'Nenhum' }
    }

    if serverJobs then
        for i = 1, #serverJobs do
            options[#options + 1] = {
                value = serverJobs[i].name,
                label = serverJobs[i].label
            }
        end
    end

    return options
end

local function getConfiguredItemList()
    local configuredItems = PR.ItemList or {}
    local items = {}

    for i = 1, #configuredItems do
        items[#items + 1] = configuredItems[i]
    end

    if #items == 0 then
        for itemName, itemData in pairs(configuredItems) do
            if type(itemData) == 'table' then
                items[#items + 1] = {
                    item = itemData.item or itemData.name or itemName,
                    label = itemData.label or itemData.item or itemData.name or itemName,
                    image = itemData.image
                }
            elseif type(itemData) == 'string' then
                items[#items + 1] = {
                    item = itemData,
                    label = itemData
                }
            end
        end
    end

    if #items == 0 then
        return {
            {
                item = PR.keycardItem or 'elevator_card',
                label = PR.keycardItem or 'elevator_card'
            }
        }
    end

    return items
end

local function getItemName(itemData)
    if type(itemData) == 'table' then return itemData.item or itemData.name end
    return itemData
end

local function getItemLabel(itemData)
    if type(itemData) == 'table' then return itemData.label or itemData.item or itemData.name end
    return itemData
end

local function getItemImage(itemData)
    if type(itemData) == 'table' and itemData.image then return itemData.image end

    local item = getItemName(itemData)
    if not item or not PR.InventoryImagePath then return nil end

    return PR.InventoryImagePath:format(item)
end

local function buildKeycardItemOptions()
    local options = {
        { value = 'none', label = 'Qualquer cartao configurado' }
    }
    local items = getConfiguredItemList()

    for i = 1, #items do
        local item = getItemName(items[i])
        if item then
            options[#options + 1] = {
                value = item,
                label = getItemLabel(items[i]) or item
            }
        end
    end

    return options
end

local function validateAccessFields(accessType, job, password, accessKey, citizenid)
    if (accessType == 'job' or accessType == 'gang' or accessType == 'job_citizenid' or accessType == 'job_keycard' or accessType == 'job_password') and not job then
        notify(lang('menu.title'), lang('menu.error_job_required'), 'error')
        return false
    end

    if (accessType == 'password' or accessType == 'job_password') and not password then
        notify(lang('menu.title'), lang('menu.error_password_required'), 'error')
        return false
    end

    if (accessType == 'keycard' or accessType == 'job_keycard') and not accessKey then
        notify(lang('menu.title'), lang('menu.error_keycard_required'), 'error')
        return false
    end

    if (accessType == 'citizenid' or accessType == 'job_citizenid') and not citizenid then
        notify(lang('menu.title'), lang('menu.error_citizenid_required'), 'error')
        return false
    end

    return true
end

local function decodeJson(value)
    if type(value) ~= 'string' then return value end

    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end

    return nil
end

local function roundNumber(value, decimals)
    local multiplier = 10 ^ (decimals or 4)
    value = tonumber(value) or 0.0

    if value >= 0 then
        return math.floor(value * multiplier + 0.5) / multiplier
    end

    return math.ceil(value * multiplier - 0.5) / multiplier
end

local function parseNumbers(value)
    if not value then return nil end

    local nums = {}
    for val in tostring(value):gmatch("[-+]?%d*%.?%d+") do
        nums[#nums + 1] = tonumber(val)
    end

    return nums
end

local function getCoordsTable(value)
    if not value then return nil end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    if not x or not y or not z then return nil end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function getRotationTable(value)
    if not value then return nil end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    if not x or not y or not z then return nil end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function normalizeSpawnData(value)
    value = decodeJson(value)
    if not value then return nil end

    local coords = getCoordsTable(value)
    if not coords then return nil end

    coords.heading = tonumber(value.heading or value.w or value[4]) or 0.0
    return coords
end

local function isDuiInteract(value)
    value = decodeJson(value)
    if type(value) ~= 'table' then return false end

    return value.mode == 'dui'
        or value.type == 'dui'
        or value.type == 'prop'
        or value.model ~= nil
        or value.modelName ~= nil
        or value.rotation ~= nil
end

local function normalizeInteractData(value)
    value = decodeJson(value)
    if not value then return nil end

    local rawCoords = value.coords or value.position or value
    local coords = getCoordsTable(rawCoords)
    if not coords then return nil end

    if isDuiInteract(value) then
        local rotation = getRotationTable(value.rotation or value.rot)
        local heading = tonumber(value.heading or rawCoords.heading or rawCoords.w or rawCoords[4])
            or (rotation and rotation.z)
            or 0.0

        return {
            mode = 'dui',
            type = 'prop',
            model = tonumber(value.model) or DUI_KEYPAD_MODEL,
            modelName = value.modelName or DUI_KEYPAD_MODEL_NAME,
            coords = coords,
            rotation = rotation or {
                x = 0.0,
                y = 0.0,
                z = heading
            },
            heading = heading
        }
    end

    return coords
end

local function getInteractCoords(value)
    value = normalizeInteractData(value)
    if not value then return nil end

    return value.coords or value
end

local function formatSpawnInput(value)
    local coords = normalizeSpawnData(value)
    if not coords then return "" end

    return string.format("%.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, coords.heading or 0.0)
end

local function formatInteractSummary(value)
    local interact = normalizeInteractData(value)
    if not interact then return "N/A" end

    local coords = interact.coords or interact
    local heading = interact.heading or coords.heading or 0.0

    if interact.mode == 'dui' then
        local rotation = interact.rotation or { x = 0.0, y = 0.0, z = heading }
        return string.format(
            "DUI X: %.2f | Y: %.2f | Z: %.2f | H: %.2f | Rot: %.2f, %.2f, %.2f",
            coords.x,
            coords.y,
            coords.z,
            heading,
            rotation.x or 0.0,
            rotation.y or 0.0,
            rotation.z or 0.0
        )
    end

    return string.format("X: %.2f | Y: %.2f | Z: %.2f", coords.x, coords.y, coords.z)
end

local function formatInteractInput(value)
    local interact = normalizeInteractData(value)
    if not interact then return "" end

    if interact.mode == 'dui' then
        return json.encode(interact)
    end

    return string.format("%.2f, %.2f, %.2f", interact.x, interact.y, interact.z)
end

local function parseSpawnInput(value)
    local nums = parseNumbers(value)
    if not nums or #nums < 3 then return nil end

    return {
        x = nums[1],
        y = nums[2],
        z = nums[3],
        heading = nums[4] or 0.0
    }
end

local function parseInteractInput(value)
    if type(value) == 'table' then
        return normalizeInteractData(value)
    end

    local str = tostring(value or '')
    local trimmed = str:gsub("^%s+", ""):gsub("%s+$", "")

    if trimmed:sub(1, 1) == "{" then
        local decoded = decodeJson(trimmed)
        local normalized = normalizeInteractData(decoded)
        if normalized then return normalized end
    end

    local nums = parseNumbers(trimmed)
    if not nums or #nums < 3 then return nil end

    if trimmed:lower():find("dui", 1, true) or #nums >= 7 then
        local heading = nums[4] or nums[7] or 0.0
        return {
            mode = 'dui',
            type = 'prop',
            model = DUI_KEYPAD_MODEL,
            modelName = DUI_KEYPAD_MODEL_NAME,
            coords = {
                x = nums[1],
                y = nums[2],
                z = nums[3]
            },
            heading = heading,
            rotation = {
                x = nums[5] or 0.0,
                y = nums[6] or 0.0,
                z = nums[7] or heading
            }
        }
    end

    return {
        x = nums[1],
        y = nums[2],
        z = nums[3]
    }
end

local function wasControlReleased(controlId)
    return IsControlJustReleased(0, controlId)
        or IsDisabledControlJustReleased(0, controlId)
        or IsControlJustReleased(2, controlId)
        or IsDisabledControlJustReleased(2, controlId)
end

local function isRightMouseActive()
    return IsControlPressed(0, 25)
        or IsDisabledControlPressed(0, 25)
        or IsControlJustPressed(0, 25)
        or IsDisabledControlJustPressed(0, 25)
        or IsControlJustReleased(0, 25)
        or IsDisabledControlJustReleased(0, 25)
        or IsControlPressed(2, 25)
        or IsDisabledControlPressed(2, 25)
        or IsControlJustPressed(2, 25)
        or IsDisabledControlJustPressed(2, 25)
        or IsControlJustReleased(2, 25)
        or IsDisabledControlJustReleased(2, 25)
end

local function buildDuiPayloadFromEntity(entity)
    local coords = GetEntityCoords(entity)
    local rotation = GetEntityRotation(entity, 2)

    return {
        mode = 'dui',
        type = 'prop',
        model = GetEntityModel(entity),
        modelName = DUI_KEYPAD_MODEL_NAME,
        coords = {
            x = roundNumber(coords.x, 4),
            y = roundNumber(coords.y, 4),
            z = roundNumber(coords.z, 4)
        },
        rotation = {
            x = roundNumber(rotation.x, 4),
            y = roundNumber(rotation.y, 4),
            z = roundNumber(rotation.z, 4)
        },
        heading = roundNumber(GetEntityHeading(entity), 4)
    }
end

local function createDuiPlacementProp(existingInteract)
    if type(CreateDUI) == 'function' then
        CreateDUI()
    end

    local ped = PlayerPedId()
    local placement = normalizeInteractData(existingInteract)
    local coords = placement and (placement.coords or placement)
    local heading = placement and (placement.heading or coords.heading) or nil
    local rotation = placement and placement.rotation or nil
    local model = placement and placement.model or DUI_KEYPAD_MODEL

    lib.requestModel(model)

    if not coords then
        local forwardCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.45)
        coords = {
            x = forwardCoords.x,
            y = forwardCoords.y,
            z = forwardCoords.z
        }
        heading = GetEntityHeading(ped)
    end

    local prop = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    if not prop or prop == 0 then return nil end

    SetEntityAsMissionEntity(prop, true, true)
    if rotation then
        SetEntityRotation(prop, rotation.x or 0.0, rotation.y or 0.0, rotation.z or heading or 0.0, 2, true)
    else
        SetEntityHeading(prop, heading or 0.0)
    end
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, false)
    SetEntityAlpha(prop, 210, false)

    return prop
end

local function captureDuiInteractPlacement(existingInteract)
    local gizmo = pr_lib.gizmo or (pr_lib.fivem and pr_lib.fivem.gizmo)
    if not gizmo or type(gizmo.start) ~= 'function' then
        notify(lang('menu.title'), lang('menu.error_gizmo_unavailable') or 'Gizmo indisponivel no pr_bridge.', 'error')
        return nil
    end

    local prop = createDuiPlacementProp(existingInteract)
    if not prop then
        notify(lang('menu.title'), lang('menu.error_dui_position') or 'Nao foi possivel criar o prop DUI.', 'error')
        return nil
    end

    lib.showTextUI(lang('menu.textui_position_dui') or [[
**[ENTER]** - Confirmar posicao do prop
**[BACKSPACE/ESC]** - Cancelar
**[R]** - Alternar mover/rotacionar
**[G]** - Encaixar no chao
**[F]** - Alternar camera
**[TAB]** - Precisao
]])

    gizmo.start(prop, function()
        return true
    end, nil, {
        showPreview = true,
        previewTitle = 'DUI Keypad',
        precisionMode = false,
        freeCameraMode = false,
        allowFreeCameraToggle = true,
        useEditorCamera = true,
        editorCameraRadius = 1.6,
    })

    local confirmed = false
    local ignoreCancelUntil = 0

    while DoesEntityExist(prop) do
        Wait(0)

        if isRightMouseActive() then
            ignoreCancelUntil = GetGameTimer() + 150
        end

        if wasControlReleased(201) or wasControlReleased(191) then
            confirmed = true
            break
        end

        if GetGameTimer() >= ignoreCancelUntil and (wasControlReleased(177) or wasControlReleased(202) or wasControlReleased(200)) then
            break
        end
    end

    if gizmo.stop then
        gizmo.stop()
    end

    lib.hideTextUI()

    local payload = nil
    if confirmed and DoesEntityExist(prop) then
        payload = buildDuiPayloadFromEntity(prop)
    end

    if DoesEntityExist(prop) then
        DeleteEntity(prop)
    end

    return payload
end

-- Menu Principal de Gerenciamento
OpenManageMenu = function()
    CreateThread(function()
        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_manage_menu',
            title = lang('menu.title'),
            options = {
                {
                    title = lang('menu.manage_elevators'),
                    icon = 'elevator',
                    onSelect = function()
                        OpenElevatorListMenu()
                    end
                },
                {
                    title = lang('menu.create_elevator'),
                    icon = 'plus',
                    onSelect = function()
                        CreateElevatorMenu()
                    end
                },
                {
                    title = lang('menu.create_floor'),
                    icon = 'stairs',
                    onSelect = function()
                        CreateFloorMenu()
                    end
                },
                {
                    title = lang('menu.create_item'),
                    icon = 'key',
                    onSelect = function()
                        CreateItemMenu()
                    end
                }
            }
        })
        pr_lib.menu.ShowContext('pr_elevator_manage_menu')
    end)
end

-- Listagem de Elevadores
OpenElevatorListMenu = function()
    CreateThread(function()
        local elevators = pr_lib.callback.await('pr_elevator:server:getElevators')
        if not elevators or #elevators == 0 then
            notify(lang('menu.title'), lang('menu.no_elevators'), 'error')
            return
        end

        local options = {}
        for i = 1, #elevators do
            local el = elevators[i]
            table.insert(options, {
                title = el.name or ("ID: " .. el.id),
                description = ("ID: %s"):format(el.id),
                onSelect = function()
                    OpenElevatorControlMenu(el)
                end
            })
        end

        table.insert(options, {
            title = '← Voltar',
            onSelect = function()
                OpenManageMenu()
            end
        })

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_list_menu',
            title = lang('menu.elevator_list'),
            menu = 'pr_elevator_manage_menu',
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_list_menu')
    end)
end

-- Controle de um Elevador Específico
OpenElevatorControlMenu = function(el)
    CreateThread(function()
        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_control_menu',
            title = el.name,
            menu = 'pr_elevator_list_menu',
            options = {
                {
                    title = lang('menu.view_floors'),
                    icon = 'layer-group',
                    onSelect = function()
                        OpenFloorListMenu(el)
                    end
                },
                {
                    title = lang('menu.edit_elevator'),
                    icon = 'pen-to-square',
                    onSelect = function()
                        OpenElevatorEditInputDialog(el)
                    end
                },
                {
                    title = lang('menu.delete_elevator'),
                    icon = 'trash',
                    onSelect = function()
                        local confirm = pr_lib.menu.AlertDialog({
                            header = lang('menu.delete_elevator'),
                            content = lang('menu.delete_elevator_confirm') .. '\n' .. lang('menu.delete_elevator_desc'),
                            cancel = true
                        })
                        if confirm == 'confirm' then
                            TriggerServerEvent('pr_elevator:server:deleteElevator', el.id)
                        else
                            OpenElevatorControlMenu(el)
                        end
                    end
                },
                {
                    title = '← Voltar',
                    onSelect = function()
                        OpenElevatorListMenu()
                    end
                }
            }
        })
        pr_lib.menu.ShowContext('pr_elevator_control_menu')
    end)
end

OpenElevatorEditInputDialog = function(el)
    CreateThread(function()
        local input = pr_lib.menu.InputDialog(lang('menu.edit_elevator') .. " - " .. (el.name or el.id), {
            {type = 'input', label = lang('menu.form_name'), description = lang('menu.desc_name'), default = el.name, required = true},
        })

        if not input then
            OpenElevatorControlMenu(el)
            return
        end

        local name = input[1]
        if not name or name == "" then
            notify(lang('menu.title'), lang('menu.error_fields'), 'error')
            OpenElevatorControlMenu(el)
            return
        end

        el.name = name
        TriggerServerEvent('pr_elevator:server:updateElevator', el.id, name)
        OpenElevatorControlMenu(el)
    end)
end

-- Listagem de Andares
OpenFloorListMenu = function(el)
    CreateThread(function()
        local floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, el.id)
        local options = {}

        if floors and #floors > 0 then
            for i = 1, #floors do
                local fl = floors[i]

                local currentCoords = normalizeSpawnData(fl.coords)
                local currentInteract = normalizeInteractData(fl.interact_coords)

                local cx, cy, cz = 0.0, 0.0, 0.0
                if currentCoords then
                    cx = currentCoords.x or 0.0
                    cy = currentCoords.y or 0.0
                    cz = currentCoords.z or 0.0
                end

                table.insert(options, {
                    title = lang('menu.floor_detail'):format(fl.floor, fl.name),
                    description = fl.coords and ("Coords registradas"),
                    metadata = {
                        {label = lang('menu.meta_coords'), value = string.format("X: %.2f | Y: %.2f | Z: %.2f", cx, cy, cz)},
                        {label = lang('menu.meta_interact'), value = formatInteractSummary(currentInteract)},
                        {label = lang('menu.meta_color_theme'), value = fl.theme_color or 'N/A'},
                        {label = lang('menu.meta_color_bg'), value = fl.theme_background or 'N/A'},
                        {label = lang('menu.meta_distance'), value = fl.distance or 2.0}
                    },
                    onSelect = function()
                        OpenFloorControlMenu(el, fl)
                    end
                })
            end
        else
            table.insert(options, {
                title = lang('menu.no_floors'),
                disabled = true
            })
        end

        table.insert(options, {
            title = '← Voltar',
            onSelect = function()
                OpenElevatorControlMenu(el)
            end
        })

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_floor_list_menu',
            title = lang('menu.floor_list'):format(el.name),
            menu = 'pr_elevator_control_menu',
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_floor_list_menu')
    end)
end

-- Controle de um Andar Específico
OpenFloorControlMenu = function(el, fl)
    CreateThread(function()
        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_floor_control_menu',
            title = lang('menu.floor_detail'):format(fl.floor, fl.name),
            menu = 'pr_elevator_floor_list_menu',
            options = {
                {
                    title = lang('menu.teleport_to_floor'),
                    icon = 'location-arrow',
                    onSelect = function()
                        local coords = fl.coords
                        if type(coords) == 'string' then
                            coords = json.decode(coords)
                        end
                        if coords then
                            local x, y, z = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
                            local heading = coords.heading or coords[4] or 0.0
                            local ped = PlayerPedId()
                            SetEntityCoords(ped, x, y, z, false, false, false, false)
                            SetEntityHeading(ped, heading)
                            notify(lang('menu.title'), lang('menu.teleport_to_floor'), 'success')
                        end
                        OpenFloorControlMenu(el, fl)
                    end
                },
                {
                    title = lang('menu.edit_floor'),
                    icon = 'pen-to-square',
                    onSelect = function()
                        OpenFloorEditInputDialog(el, fl)
                    end
                },
                {
                    title = lang('menu.position_dui') or 'Reposicionar Prop DUI',
                    icon = 'up-down-left-right',
                    onSelect = function()
                        OpenFloorDuiPlacementEditor(el, fl)
                    end
                },
                {
                    title = lang('menu.delete_floor'),
                    icon = 'trash',
                    onSelect = function()
                        local confirm = pr_lib.menu.AlertDialog({
                            header = lang('menu.delete_floor'),
                            content = lang('menu.delete_floor_confirm'),
                            cancel = true
                        })
                        if confirm == 'confirm' then
                            TriggerServerEvent('pr_elevator:server:deleteFloor', fl.id)
                        else
                            OpenFloorControlMenu(el, fl)
                        end
                    end
                },
                {
                    title = '← Voltar',
                    onSelect = function()
                        OpenFloorListMenu(el)
                    end
                }
            }
        })
        pr_lib.menu.ShowContext('pr_elevator_floor_control_menu')
    end)
end

-- Formulário de Criação de Elevador
CreateElevatorMenu = function()
    CreateThread(function()
        local input = pr_lib.menu.InputDialog(lang('menu.create_elevator'), {
            {type = 'input', label = lang('menu.form_name'), description = lang('menu.desc_name'), required = true},
        })

        if not input then
            OpenManageMenu()
            return
        end

        local name = input[1]

        if not name or name == "" then
            notify(lang('menu.title'), lang('menu.error_fields'), 'error')
            OpenManageMenu()
            return
        end

        TriggerServerEvent('pr_elevator:server:createElevator', name, 'public', nil, 0, nil, nil, nil)
    end)
end

-- Formulário de Criação de Andar
CreateFloorMenu = function()
    CreateThread(function()
        -- 1. Obter a lista de elevadores para seleção inicial
        local elevators = pr_lib.callback.await('pr_elevator:server:getElevators')
        if not elevators or #elevators == 0 then
            notify(lang('menu.title'), lang('menu.no_elevators_to_floor'), 'error')
            OpenManageMenu()
            return
        end

        local elevatorOptions = {}
        for i = 1, #elevators do
            local el = elevators[i]
            table.insert(elevatorOptions, {
                title = el.name or ("ID: " .. el.id),
                description = ("ID: %s"):format(el.id),
                onSelect = function()
                    -- Uma vez que selecionou o elevador, prosseguir para o formulário
                    OpenFloorDetailsInputDialog(el)
                end
            })
        end

        table.insert(elevatorOptions, {
            title = '← Voltar',
            onSelect = function()
                OpenManageMenu()
            end
        })

        -- Registrar e mostrar o menu de seleção do elevador
        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_select_for_floor',
            title = lang('menu.select_elevator'),
            menu = 'pr_elevator_manage_menu',
            options = elevatorOptions
        })
        pr_lib.menu.ShowContext('pr_elevator_select_for_floor')
    end)
end

-- Diálogo de Detalhes do Andar para o Elevador Selecionado
OpenFloorDetailsInputDialog = function(el, presetSpawn, presetInteract)
    CreateThread(function()
        local floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, el.id)
        local usedOrders = {}
        if floors then
            for i = 1, #floors do
                usedOrders[floors[i].floor] = true
            end
        end

        -- Montar as ordens disponíveis (de 1 a 50) omitindo as já usadas
        local orderOptions = {}
        for i = 1, 50 do
            if not usedOrders[i] then
                table.insert(orderOptions, {
                    value = i,
                    label = tostring(i)
                })
            end
        end

        -- Se por algum motivo todas as ordens estiverem cheias
        if #orderOptions == 0 then
            notify(lang('menu.title'), 'Limite de andares atingido.', 'error')
            CreateFloorMenu()
            return
        end

        local spawnStr = type(presetSpawn) == 'table' and formatSpawnInput(presetSpawn) or presetSpawn
        local interactStr = type(presetInteract) == 'table' and formatInteractInput(presetInteract) or presetInteract
        local floorNameOptions = buildFloorNameOptions()
        local accessTypeOptions = buildAccessTypeOptions()
        local jobOptions = buildJobOptions(pr_lib.callback.await('pr_elevator:server:getJobsList'))
        local keycardItemOptions = buildKeycardItemOptions()

        if not spawnStr or not interactStr then
            -- 1. Prompt player to stand at spawn point
            local ped = PlayerPedId()
            lib.showTextUI(lang('menu.textui_position_spawn') or "Posicione-se onde será o spawn do andar e pressione ~g~[E]~s~ para marcar ou ~r~[BACKSPACE]~s~ para cancelar")
            
            local spawnCoords = nil
            local spawnHeading = nil
            
            while true do
                Wait(0)
                if IsControlJustReleased(0, 38) then -- E
                    spawnCoords = GetEntityCoords(ped)
                    spawnHeading = GetEntityHeading(ped)
                    break
                elseif IsControlJustReleased(0, 177) or IsControlJustReleased(0, 202) then -- Backspace / ESC
                    lib.hideTextUI()
                    CreateFloorMenu()
                    return
                end
            end
            
            lib.hideTextUI()
            spawnStr = string.format("%.2f, %.2f, %.2f, %.2f", spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading)
            
            -- Wait a brief moment to avoid E key press carrying over
            Wait(200)
            
            -- 2. Position the DUI keypad prop with pr_bridge gizmo
            local interactPayload = captureDuiInteractPlacement()
            if not interactPayload then
                CreateFloorMenu()
                return
            end

            interactStr = formatInteractInput(interactPayload)
            local interactInputStr = interactStr
            interactStr = formatInteractSummary(interactPayload)
            -- 3. Confirm both coordinates using AlertDialog
            local confirm = pr_lib.menu.AlertDialog({
                header = lang('menu.confirm_coords_header') or "Confirmar Coordenadas",
                content = (lang('menu.confirm_coords_content') or "Deseja confirmar as coordenadas marcadas?\n\nSpawn: %s\nInteração: %s"):format(spawnStr, interactStr),
                cancel = true
            })
            
            if confirm ~= 'confirm' then
                OpenFloorDetailsInputDialog(el)
                return
            end
            interactStr = interactInputStr
        end

        local input = pr_lib.menu.InputDialog(lang('menu.create_floor') .. " - " .. el.name, {
            {type = 'select', label = lang('menu.form_floor_name'), description = lang('menu.desc_floor_name'), options = floorNameOptions, default = 'T', required = true},
            {type = 'select', label = lang('menu.form_floor_order'), description = lang('menu.desc_floor_order'), options = orderOptions, default = orderOptions[1].value, required = true},
            {type = 'number', label = lang('menu.form_distance'), description = lang('menu.desc_distance'), default = 2.0},
            {type = 'color', label = lang('menu.form_theme_color'), description = lang('menu.desc_theme_color'), default = '#00F8B8'},
            {type = 'color', label = lang('menu.form_theme_background'), description = lang('menu.desc_theme_background'), default = '#1E7F7E'},
            {type = 'input', label = lang('menu.form_coords_spawn'), description = lang('menu.desc_coords_spawn'), default = spawnStr, required = true},
            {type = 'input', label = lang('menu.form_coords_interact'), description = lang('menu.desc_coords_interact'), default = interactStr, required = true},
            {type = 'select', label = lang('menu.form_floor_access_type'), description = lang('menu.desc_floor_access_type'), options = accessTypeOptions, default = 'public', required = true},
            {type = 'select', label = lang('menu.form_jobs_select'), description = lang('menu.desc_jobs_select'), options = jobOptions, default = 'none'},
            {type = 'number', label = lang('menu.form_job_grade'), description = lang('menu.desc_job_grade'), default = 0},
            {type = 'input', label = lang('menu.form_password'), description = lang('menu.desc_password')},
            {type = 'select', label = lang('menu.form_keycard_item'), description = lang('menu.desc_keycard_item'), options = keycardItemOptions, default = 'none'},
            {type = 'input', label = lang('menu.form_access_key'), description = lang('menu.desc_access_key')},
            {type = 'input', label = lang('menu.form_citizenid'), description = lang('menu.desc_citizenid')},
        })

        if not input then
            CreateFloorMenu()
            return
        end

        local floorName = input[1]
        local floorOrder = tonumber(input[2])
        local distance = tonumber(input[3]) or 2.0
        local themeColor = input[4]
        local themeBackground = input[5]
        local coordsSpawnStr = input[6]
        local coordsInteractStr = input[7]
        local accessType = input[8] or 'public'
        local accessJob = normalizeEmpty(input[9])
        local accessJobGrade = tonumber(input[10]) or 0
        local accessPassword = normalizeEmpty(input[11])
        local accessItem = normalizeEmpty(input[12])
        local accessKey = normalizeEmpty(input[13])
        local accessCitizenid = normalizeEmpty(input[14])

        -- Validar se os campos obrigatórios estão preenchidos
        if not floorName or floorName == "" or not floorOrder or not coordsSpawnStr or not coordsInteractStr then
            notify(lang('menu.title'), lang('menu.error_fields'), 'error')
            OpenFloorDetailsInputDialog(el, coordsSpawnStr, coordsInteractStr)
            return
        end

        local spawnTable = parseSpawnInput(coordsSpawnStr)
        local interactTable = parseInteractInput(coordsInteractStr)

        if not spawnTable or not interactTable then
            notify(lang('menu.title'), lang('menu.error_invalid_coords'), 'error')
            OpenFloorDetailsInputDialog(el, coordsSpawnStr, coordsInteractStr)
            return
        end

        if not validateAccessFields(accessType, accessJob, accessPassword, accessKey, accessCitizenid) then
            OpenFloorDetailsInputDialog(el, coordsSpawnStr, coordsInteractStr)
            return
        end

        TriggerServerEvent('pr_elevator:server:createFloor', el.id, floorName, floorOrder, distance, themeColor, themeBackground, spawnTable, interactTable, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid)
    end)
end

-- Diálogo de Edição de Detalhes do Andar
OpenFloorDuiPlacementEditor = function(el, fl)
    CreateThread(function()
        local floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, el.id)
        local currentFloorData = fl

        if floors then
            for i = 1, #floors do
                if floors[i].id == fl.id then
                    currentFloorData = floors[i]
                    break
                end
            end
        end

        local spawnTable = normalizeSpawnData(currentFloorData.coords)
        if not spawnTable then
            notify(lang('menu.title'), lang('menu.error_invalid_coords'), 'error')
            OpenFloorControlMenu(el, currentFloorData)
            return
        end

        local interactPayload = captureDuiInteractPlacement(currentFloorData.interact_coords)
        if not interactPayload then
            OpenFloorControlMenu(el, currentFloorData)
            return
        end

        TriggerServerEvent(
            'pr_elevator:server:updateFloor',
            currentFloorData.id,
            el.id,
            currentFloorData.name,
            currentFloorData.floor,
            currentFloorData.distance or 2.0,
            currentFloorData.theme_color,
            currentFloorData.theme_background,
            spawnTable,
            interactPayload,
            currentFloorData.access_type or 'public',
            currentFloorData.access_job,
            currentFloorData.access_job_grade or 0,
            currentFloorData.access_password,
            currentFloorData.access_key,
            currentFloorData.access_item,
            currentFloorData.access_citizenid,
            nil,
            currentFloorData.floor
        )

        currentFloorData.interact_coords = interactPayload
        notify(lang('menu.title'), lang('menu.dui_position_updated') or lang('menu.floor_updated'), 'success')
        OpenFloorControlMenu(el, currentFloorData)
    end)
end

OpenFloorEditInputDialog = function(el, fl)
    CreateThread(function()
        local floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, el.id)
        local usedOrders = {}
        local currentFloorData = nil
        if floors then
            for i = 1, #floors do
                usedOrders[floors[i].floor] = true
                if floors[i].id == fl.id then
                    currentFloorData = floors[i]
                end
            end
        end

        -- Se por algum motivo não encontrou no banco, usa a tabela original enviada por segurança
        if not currentFloorData then
            currentFloorData = fl
        end

        local orderOptions = {}
        for i = 1, 50 do
            local label = tostring(i)
            if usedOrders[i] then
                if i == currentFloorData.floor then
                    label = label .. " (" .. lang('menu.current') .. ")"
                else
                    label = label .. " (" .. lang('menu.in_use') .. ")"
                end
            end
            table.insert(orderOptions, {
                value = i,
                label = label
            })
        end

        local currentCoords = normalizeSpawnData(currentFloorData.coords)
        local currentInteract = normalizeInteractData(currentFloorData.interact_coords)

        local defaultSpawn = formatSpawnInput(currentCoords)
        local defaultInteract = formatInteractInput(currentInteract)
        local floorNameOptions = buildFloorNameOptions()
        local accessTypeOptions = buildAccessTypeOptions()
        local jobOptions = buildJobOptions(pr_lib.callback.await('pr_elevator:server:getJobsList'))
        local keycardItemOptions = buildKeycardItemOptions()

        local input = pr_lib.menu.InputDialog(lang('menu.edit_floor') .. " - " .. currentFloorData.name, {
            {type = 'select', label = lang('menu.form_floor_name'), description = lang('menu.desc_floor_name'), options = floorNameOptions, default = currentFloorData.name or 'T', required = true},
            {type = 'select', label = lang('menu.form_floor_order'), description = lang('menu.desc_floor_order'), options = orderOptions, default = currentFloorData.floor, required = true},
            {type = 'number', label = lang('menu.form_distance'), description = lang('menu.desc_distance'), default = currentFloorData.distance or 2.0},
            {type = 'color', label = lang('menu.form_theme_color'), description = lang('menu.desc_theme_color'), default = currentFloorData.theme_color or '#00F8B8'},
            {type = 'color', label = lang('menu.form_theme_background'), description = lang('menu.desc_theme_background'), default = currentFloorData.theme_background or '#1E7F7E'},
            {type = 'input', label = lang('menu.form_coords_spawn'), description = lang('menu.desc_coords_spawn'), default = defaultSpawn, required = true},
            {type = 'input', label = lang('menu.form_coords_interact'), description = lang('menu.desc_coords_interact'), default = defaultInteract, required = true},
            {type = 'select', label = lang('menu.form_floor_access_type'), description = lang('menu.desc_floor_access_type'), options = accessTypeOptions, default = currentFloorData.access_type or 'public', required = true},
            {type = 'select', label = lang('menu.form_jobs_select'), description = lang('menu.desc_jobs_select'), options = jobOptions, default = currentFloorData.access_job or 'none'},
            {type = 'number', label = lang('menu.form_job_grade'), description = lang('menu.desc_job_grade'), default = currentFloorData.access_job_grade or 0},
            {type = 'input', label = lang('menu.form_password'), description = lang('menu.desc_password'), default = currentFloorData.access_password},
            {type = 'select', label = lang('menu.form_keycard_item'), description = lang('menu.desc_keycard_item'), options = keycardItemOptions, default = currentFloorData.access_item or 'none'},
            {type = 'input', label = lang('menu.form_access_key'), description = lang('menu.desc_access_key'), default = currentFloorData.access_key},
            {type = 'input', label = lang('menu.form_citizenid'), description = lang('menu.desc_citizenid'), default = currentFloorData.access_citizenid},
        })

        if not input then
            OpenFloorControlMenu(el, currentFloorData)
            return
        end

        local floorName = input[1]
        local floorOrder = tonumber(input[2])
        local distance = tonumber(input[3]) or 2.0
        local themeColor = input[4]
        local themeBackground = input[5]
        local coordsSpawnStr = input[6]
        local coordsInteractStr = input[7]
        local accessType = input[8] or 'public'
        local accessJob = normalizeEmpty(input[9])
        local accessJobGrade = tonumber(input[10]) or 0
        local accessPassword = normalizeEmpty(input[11])
        local accessItem = normalizeEmpty(input[12])
        local accessKey = normalizeEmpty(input[13])
        local accessCitizenid = normalizeEmpty(input[14])

        if not floorName or floorName == "" or not floorOrder or not coordsSpawnStr or not coordsInteractStr then
            notify(lang('menu.title'), lang('menu.error_fields'), 'error')
            OpenFloorEditInputDialog(el, currentFloorData)
            return
        end

        local spawnTable = parseSpawnInput(coordsSpawnStr)
        local interactTable = parseInteractInput(coordsInteractStr)

        if not spawnTable or not interactTable then
            notify(lang('menu.title'), lang('menu.error_invalid_coords'), 'error')
            OpenFloorEditInputDialog(el, currentFloorData)
            return
        end

        if not validateAccessFields(accessType, accessJob, accessPassword, accessKey, accessCitizenid) then
            OpenFloorEditInputDialog(el, currentFloorData)
            return
        end

        local targetSwapFloorId = nil
        local targetSwapFloorName = nil
        if floorOrder ~= currentFloorData.floor then
            for i = 1, #floors do
                local otherFl = floors[i]
                if otherFl.id ~= currentFloorData.id and otherFl.floor == floorOrder then
                    targetSwapFloorId = otherFl.id
                    targetSwapFloorName = otherFl.name
                    break
                end
            end
        end

        if targetSwapFloorId then
            local confirm = pr_lib.menu.AlertDialog({
                header = lang('menu.swap_floors_header'),
                content = lang('menu.swap_floors_confirm'):format(floorOrder, targetSwapFloorName, floorOrder, targetSwapFloorName, currentFloorData.floor),
                cancel = true
            })
            if confirm ~= 'confirm' then
                OpenFloorEditInputDialog(el, currentFloorData)
                return
            end
            notify(lang('menu.title'), lang('menu.floor_swapped'):format(currentFloorData.floor, floorOrder), 'success')
        else
            notify(lang('menu.title'), lang('menu.floor_updated'), 'success')
        end

        TriggerServerEvent('pr_elevator:server:updateFloor', currentFloorData.id, el.id, floorName, floorOrder, distance, themeColor, themeBackground, spawnTable, interactTable, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid, targetSwapFloorId, currentFloorData.floor)
    end)
end

-- Formulário de Criação de Item (Cartão)
CreateItemMenu = function()
    CreateThread(function()
        local items = getConfiguredItemList()
        local options = {}

        for i = 1, #items do
            local item = getItemName(items[i])
            if item then
                options[#options + 1] = {
                    title = getItemLabel(items[i]) or item,
                    description = item,
                    image = getItemImage(items[i]),
                    metadata = {
                        { label = 'Item', value = item }
                    },
                    onSelect = function()
                        local input = pr_lib.menu.InputDialog(lang('menu.create_item'), {
                            {type = 'input', label = lang('menu.form_keycard_access_key'), description = lang('menu.desc_access_key'), required = true},
                        })

                        if not input then
                            CreateItemMenu()
                            return
                        end

                        local accessKey = input[1]
                        if not accessKey or accessKey == "" then
                            notify(lang('menu.title'), lang('menu.error_fields'), 'error')
                            CreateItemMenu()
                            return
                        end

                        TriggerServerEvent('pr_elevator:server:giveKeycard', item, accessKey)
                    end
                }
            end
        end

        options[#options + 1] = {
            title = '← Voltar',
            onSelect = function()
                OpenManageMenu()
            end
        }

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_keycard_item_menu',
            title = lang('menu.create_item'),
            menu = 'pr_elevator_manage_menu',
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_keycard_item_menu')
    end)
end

--  Teclas de atalho para abrir o Menu.
pr_lib.addKeybind({
    name = lang('menu.elevator_keybind'),
    description = lang('menu.elevator_keybind_description'),
    defaultKey = PR.keyBinds,
    onPressed = function(self)
        OpenManageMenu()
    end,
})
