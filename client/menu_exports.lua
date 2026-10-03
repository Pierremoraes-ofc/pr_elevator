local lang = pr_lib.locale()

local ExportCreatorMenu
local ExportCreateElevatorMenu
local ExportSelectElevatorForFloorMenu
local ExportCreateFloorMenu
local ExportCreateKeycardMenu

local DUI_KEYPAD_MODEL = joaat('ch_prop_casino_keypad_01')
local DUI_KEYPAD_MODEL_NAME = 'ch_prop_casino_keypad_01'

local function notifyExport(description, notifyType)
    pr_lib.notifications.Notify({
        title = lang('menu.title'),
        description = description,
        type = notifyType or 'inform',
        duration = 5000,
        position = PR.notifyPosition
    })
end

local function normalizeEmpty(value)
    if value == nil or value == '' or value == 'none' then return nil end
    return value
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

local function decodeJson(value)
    if type(value) ~= 'string' then return value end

    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end

    return nil
end

local function buildFloorNameOptions()
    local options = {}

    for i = 10, 1, -1 do
        local value = ('S%s'):format(i)
        options[#options + 1] = { value = value, label = value }
    end

    options[#options + 1] = { value = 'T', label = 'T' }

    for i = 1, 50 do
        local value = tostring(i)
        options[#options + 1] = { value = value, label = value }
    end

    return options
end

local function buildAccessTypeOptions()
    return {
        { value = 'public', label = lang('menu.form_type_public') },
        { value = 'job', label = lang('menu.form_type_job') },
        { value = 'gang', label = lang('menu.form_type_gang') },
        { value = 'citizenid', label = lang('menu.form_type_citizenid') },
        { value = 'password', label = lang('menu.form_type_password') },
        { value = 'keycard', label = lang('menu.form_type_keycard') },
        { value = 'job_citizenid', label = lang('menu.form_type_job_citizenid') },
        { value = 'job_keycard', label = lang('menu.form_type_job_keycard') },
        { value = 'job_password', label = lang('menu.form_type_job_password') },
    }
end

local function buildJobOptions(serverJobs)
    local options = {
        { value = 'none', label = lang('menu.none') }
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
                    label = itemData.labelKey and lang(itemData.labelKey) or itemData.label or itemData.item or itemData.name or itemName,
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
    if type(itemData) == 'table' then return itemData.labelKey and lang(itemData.labelKey) or itemData.label or itemData.item or itemData.name end
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
        { value = 'none', label = lang('menu.any_keycard') }
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
        notifyExport(lang('menu.error_job_required'), 'error')
        return false
    end

    if (accessType == 'password' or accessType == 'job_password') and not password then
        notifyExport(lang('menu.error_password_required'), 'error')
        return false
    end

    if (accessType == 'keycard' or accessType == 'job_keycard') and not accessKey then
        notifyExport(lang('menu.error_keycard_required'), 'error')
        return false
    end

    if (accessType == 'citizenid' or accessType == 'job_citizenid') and not citizenid then
        notifyExport(lang('menu.error_citizenid_required'), 'error')
        return false
    end

    return true
end

local function normalizeInteractData(value)
    value = decodeJson(value)
    if not value then return nil end

    local rawCoords = value.coords or value.position or value
    local coords = getCoordsTable(rawCoords)
    if not coords then return nil end

    local isDui = value.mode == 'dui'
        or value.type == 'dui'
        or value.type == 'prop'
        or value.model ~= nil
        or value.modelName ~= nil
        or value.rotation ~= nil

    if isDui then
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

local function formatSpawnInput(value)
    local coords = parseSpawnInput(value)
    if type(value) == 'table' then
        coords = {
            x = tonumber(value.x),
            y = tonumber(value.y),
            z = tonumber(value.z),
            heading = tonumber(value.heading or value.w) or 0.0
        }
    end
    if not coords or not coords.x or not coords.y or not coords.z then return "" end

    return string.format("%.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, coords.heading or 0.0)
end

local function formatInteractInput(value)
    local interact = normalizeInteractData(value)
    if not interact then return "" end

    if interact.mode == 'dui' then
        return json.encode(interact)
    end

    return string.format("%.2f, %.2f, %.2f", interact.x, interact.y, interact.z)
end

local function formatInteractSummary(value)
    local interact = normalizeInteractData(value)
    if not interact then return "N/A" end

    local coords = interact.coords or interact
    local heading = interact.heading or coords.heading or 0.0

    if interact.mode == 'dui' then
        return string.format(
            "DUI X: %.2f | Y: %.2f | Z: %.2f | H: %.2f",
            coords.x,
            coords.y,
            coords.z,
            heading
        )
    end

    return string.format("X: %.2f | Y: %.2f | Z: %.2f", coords.x, coords.y, coords.z)
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

    pr_lib.requestModel(model)

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
    if not gizmo or type(gizmo.await) ~= 'function' then
        notifyExport(lang('menu.error_gizmo_unavailable'), 'error')
        return nil
    end

    local prop = createDuiPlacementProp(existingInteract)
    if not prop then
        notifyExport(lang('menu.error_dui_position'), 'error')
        return nil
    end

    local result = gizmo.await(prop, function()
        return true
    end, nil, {
        title = lang('menu.keypad'),
        showPreview = true,
        previewTitle = lang('menu.keypad'),
        precisionMode = false,
        freeCameraMode = false,
        allowFreeCameraToggle = true,
        useEditorCamera = true,
        editorCameraRadius = 1.6,
        restoreOnCancel = true,
    })
    local confirmed = result and result.confirmed == true

    local payload = nil
    if confirmed and DoesEntityExist(prop) then
        payload = buildDuiPayloadFromEntity(prop)
    end

    if DoesEntityExist(prop) then
        DeleteEntity(prop)
    end

    return payload
end

local function canUseExportCreator()
    local allowed = pr_lib.callback.await('pr_elevator:server:canUseCreatorExport')
    if not allowed then
        notifyExport('Voce nao tem permissao para criar elevadores.', 'error')
        return false
    end

    return true
end

ExportCreateElevatorMenu = function(context)
    CreateThread(function()
        if not canUseExportCreator() then return end
        context = context or {}

        local input = pr_lib.menu.InputDialog(lang('menu.create_elevator'), {
            { type = 'input', label = lang('menu.form_name'), description = lang('menu.desc_name'), default = context.name or context.defaultName, required = true },
        })

        if not input then
            ExportCreatorMenu(context)
            return
        end

        local name = input[1]
        if not name or name == "" then
            notifyExport(lang('menu.error_fields'), 'error')
            ExportCreatorMenu(context)
            return
        end

        TriggerServerEvent('pr_elevator:server:createElevator', name, 'public', nil, 0, nil, nil, nil)
    end)
end

ExportCreateFloorMenu = function(elevator, context, presetSpawn, presetInteract)
    CreateThread(function()
        if not canUseExportCreator() then return end
        if not elevator or not elevator.id then
            notifyExport(lang('menu.error_select_elevator'), 'error')
            return
        end

        context = context or {}
        local floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, elevator.id)
        local usedOrders = {}
        if floors then
            for i = 1, #floors do
                usedOrders[floors[i].floor] = true
            end
        end

        local orderOptions = {}
        for i = 1, 50 do
            if not usedOrders[i] or i == tonumber(context.floorOrder) then
                orderOptions[#orderOptions + 1] = {
                    value = i,
                    label = tostring(i)
                }
            end
        end

        if #orderOptions == 0 then
            notifyExport('Limite de andares atingido.', 'error')
            ExportCreatorMenu(context)
            return
        end

        local spawnStr = type(presetSpawn) == 'table' and formatSpawnInput(presetSpawn) or presetSpawn
        local interactStr = type(presetInteract) == 'table' and formatInteractInput(presetInteract) or presetInteract

        if not spawnStr or not interactStr then
            local ped = PlayerPedId()
            pr_lib.showTextUI(lang('menu.textui_position_spawn') or "Posicione-se onde sera o spawn do andar e pressione [E] para marcar ou [BACKSPACE] para cancelar")

            local spawnCoords = nil
            local spawnHeading = nil

            while true do
                Wait(0)
                if IsControlJustReleased(0, 38) then
                    spawnCoords = GetEntityCoords(ped)
                    spawnHeading = GetEntityHeading(ped)
                    break
                elseif IsControlJustReleased(0, 177) or IsControlJustReleased(0, 202) then
                    pr_lib.hideTextUI()
                    ExportCreatorMenu(context)
                    return
                end
            end

            pr_lib.hideTextUI()
            spawnStr = string.format("%.2f, %.2f, %.2f, %.2f", spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading)

            Wait(200)

            local interactPayload = captureDuiInteractPlacement()
            if not interactPayload then
                ExportCreatorMenu(context)
                return
            end

            interactStr = formatInteractInput(interactPayload)
            local interactSummary = formatInteractSummary(interactPayload)
            local confirm = pr_lib.menu.AlertDialog({
                header = lang('menu.confirm_coords_header') or "Confirmar Coordenadas",
                content = (lang('menu.confirm_coords_content') or "Deseja confirmar as coordenadas marcadas?\n\nSpawn: %s\nInteracao: %s"):format(spawnStr, interactSummary),
                cancel = true
            })

            if confirm ~= 'confirm' then
                ExportCreateFloorMenu(elevator, context)
                return
            end
        end

        local floorNameOptions = buildFloorNameOptions()
        local accessTypeOptions = buildAccessTypeOptions()
        local jobOptions = buildJobOptions(pr_lib.callback.await('pr_elevator:server:getJobsList'))
        local keycardItemOptions = buildKeycardItemOptions()

        local input = pr_lib.menu.InputDialog(lang('menu.create_floor') .. " - " .. (elevator.name or elevator.id), {
            { type = 'select', label = lang('menu.form_floor_name'), description = lang('menu.desc_floor_name'), options = floorNameOptions, default = context.floorName or 'T', required = true },
            { type = 'select', label = lang('menu.form_floor_order'), description = lang('menu.desc_floor_order'), options = orderOptions, default = tonumber(context.floorOrder) or orderOptions[1].value, required = true },
            { type = 'number', label = lang('menu.form_distance'), description = lang('menu.desc_distance'), default = tonumber(context.distance) or 2.0 },
            { type = 'color', label = lang('menu.form_theme_color'), description = lang('menu.desc_theme_color'), default = context.themeColor or '#00F8B8' },
            { type = 'color', label = lang('menu.form_theme_background'), description = lang('menu.desc_theme_background'), default = context.themeBackground or '#1E7F7E' },
            { type = 'input', label = lang('menu.form_coords_spawn'), description = lang('menu.desc_coords_spawn'), default = spawnStr, required = true },
            { type = 'input', label = lang('menu.form_coords_interact'), description = lang('menu.desc_coords_interact'), default = interactStr, required = true },
            { type = 'select', label = lang('menu.form_floor_access_type'), description = lang('menu.desc_floor_access_type'), options = accessTypeOptions, default = context.accessType or 'public', required = true },
            { type = 'select', label = lang('menu.form_jobs_select'), description = lang('menu.desc_jobs_select'), options = jobOptions, default = context.accessJob or 'none' },
            { type = 'number', label = lang('menu.form_job_grade'), description = lang('menu.desc_job_grade'), default = tonumber(context.accessJobGrade) or 0 },
            { type = 'input', label = lang('menu.form_password'), description = lang('menu.desc_password'), default = context.accessPassword },
            { type = 'select', label = lang('menu.form_keycard_item'), description = lang('menu.desc_keycard_item'), options = keycardItemOptions, default = context.accessItem or 'none' },
            { type = 'input', label = lang('menu.form_access_key'), description = lang('menu.desc_access_key'), default = context.accessKey },
            { type = 'input', label = lang('menu.form_citizenid'), description = lang('menu.desc_citizenid'), default = context.accessCitizenid },
        })

        if not input then
            ExportCreatorMenu(context)
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
            notifyExport(lang('menu.error_fields'), 'error')
            ExportCreateFloorMenu(elevator, context, coordsSpawnStr, coordsInteractStr)
            return
        end

        local spawnTable = parseSpawnInput(coordsSpawnStr)
        local interactTable = parseInteractInput(coordsInteractStr)

        if not spawnTable or not interactTable then
            notifyExport(lang('menu.error_invalid_coords'), 'error')
            ExportCreateFloorMenu(elevator, context, coordsSpawnStr, coordsInteractStr)
            return
        end

        if not validateAccessFields(accessType, accessJob, accessPassword, accessKey, accessCitizenid) then
            ExportCreateFloorMenu(elevator, context, coordsSpawnStr, coordsInteractStr)
            return
        end

        TriggerServerEvent(
            'pr_elevator:server:createFloor',
            elevator.id,
            floorName,
            floorOrder,
            distance,
            themeColor,
            themeBackground,
            spawnTable,
            interactTable,
            accessType,
            accessJob,
            accessJobGrade,
            accessPassword,
            accessKey,
            accessItem,
            accessCitizenid
        )
    end)
end

ExportSelectElevatorForFloorMenu = function(context)
    CreateThread(function()
        if not canUseExportCreator() then return end
        context = context or {}

        if context.elevatorId then
            ExportCreateFloorMenu({ id = context.elevatorId, name = context.elevatorName or context.name }, context, context.spawnCoords, context.interactCoords)
            return
        end

        local elevators = pr_lib.callback.await('pr_elevator:server:getElevators') or {}
        if #elevators == 0 then
            notifyExport(lang('menu.no_elevators_to_floor'), 'error')
            ExportCreatorMenu(context)
            return
        end

        local options = {}
        for i = 1, #elevators do
            local elevator = elevators[i]
            options[#options + 1] = {
                title = elevator.name or lang('menu.id', elevator.id),
                description = lang('menu.id', elevator.id),
                onSelect = function()
                    ExportCreateFloorMenu(elevator, context, context.spawnCoords, context.interactCoords)
                end
            }
        end

        options[#options + 1] = {
            title = lang('menu.back'),
            onSelect = function()
                ExportCreatorMenu(context)
            end
        }

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_export_select_floor_elevator',
            title = lang('menu.select_elevator'),
            menu = 'pr_elevator_export_creator_menu',
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_export_select_floor_elevator')
    end)
end

ExportCreateKeycardMenu = function(context)
    CreateThread(function()
        if not canUseExportCreator() then return end
        context = context or {}

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
                        { label = lang('menu.item'), value = item }
                    },
                    onSelect = function()
                        local input = pr_lib.menu.InputDialog(lang('menu.create_item'), {
                            { type = 'input', label = lang('menu.form_keycard_access_key'), description = lang('menu.desc_access_key'), default = context.accessKey, required = true },
                        })

                        if not input then
                            ExportCreateKeycardMenu(context)
                            return
                        end

                        local accessKey = input[1]
                        if not accessKey or accessKey == "" then
                            notifyExport(lang('menu.error_fields'), 'error')
                            ExportCreateKeycardMenu(context)
                            return
                        end

                        TriggerServerEvent('pr_elevator:server:giveKeycard', item, accessKey)
                    end
                }
            end
        end

        options[#options + 1] = {
            title = lang('menu.back'),
            onSelect = function()
                ExportCreatorMenu(context)
            end
        }

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_export_keycard_menu',
            title = lang('menu.create_item'),
            menu = 'pr_elevator_export_creator_menu',
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_export_keycard_menu')
    end)
end

ExportCreatorMenu = function(context)
    CreateThread(function()
        if not canUseExportCreator() then return end
        context = context or {}

        local options = {
            {
                title = lang('menu.create_elevator'),
                icon = 'plus',
                onSelect = function()
                    ExportCreateElevatorMenu(context)
                end
            },
            {
                title = lang('menu.create_floor'),
                icon = 'square-plus',
                onSelect = function()
                    ExportSelectElevatorForFloorMenu(context)
                end
            },
            {
                title = lang('menu.create_item'),
                icon = 'id-card',
                onSelect = function()
                    ExportCreateKeycardMenu(context)
                end
            }
        }

        pr_lib.menu.RegisterContext({
            id = 'pr_elevator_export_creator_menu',
            title = context.title or lang('menu.create_elevator'),
            options = options
        })
        pr_lib.menu.ShowContext('pr_elevator_export_creator_menu')
    end)
end

RegisterNetEvent('pr_elevator:client:openCreatorMenu', function(context)
    ExportCreatorMenu(context)
end)

RegisterCommand('prelevator_export_test', function()
    ExportCreatorMenu({
        title = lang('menu.creator_test')
    })
end, false)

exports('OpenCreatorMenu', ExportCreatorMenu)
exports('OpenCreateElevatorMenu', ExportCreateElevatorMenu)
exports('OpenCreateFloorMenu', ExportSelectElevatorForFloorMenu)
exports('OpenCreateKeycardMenu', ExportCreateKeycardMenu)
