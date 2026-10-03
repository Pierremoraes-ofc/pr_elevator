local lang = pr_lib.locale()

local runtimeElevators = {}
local renderedKeypads = {}
local textUiVisible = false
local refreshInProgress = false
local refreshRequested = false

local function getInteractionMode()
    return tostring(PR and PR.Target or 'pr_bridge'):lower()
end

local function shouldUsePrTarget()
    local mode = getInteractionMode()
    return mode == 'pr_bridge' or mode == 'target' or mode == 'both' or mode == 'all'
end

local function shouldUseInteract()
    local mode = getInteractionMode()
    return mode == 'interact' or mode == 'both' or mode == 'all'
end

local function hasConfiguredTargetStarted()
    return (shouldUsePrTarget() and GetResourceState('pr_bridge') == 'started')
        or (shouldUseInteract() and GetResourceState('pr_bridge') == 'started')
end

local function runtimeDebug(message)
    pr_lib.debug("info", ("[pr_elevator:runtime] %s"):format(message))
end

local function runtimeNotify(description, notifyType)
    if pr_lib.notifications and pr_lib.notifications.Notify then
        pr_lib.notifications.Notify({
            title = lang('menu.title'),
            description = description,
            type = notifyType or 'inform',
            duration = 3500,
            position = PR.notifyPosition
        })
        return
    end

    pr_lib.notify.Notify({
        title = lang('menu.title'),
        description = description,
        type = notifyType or 'inform',
        duration = 3500
    })
end

local function decodeJson(value)
    if type(value) ~= 'string' then return value end

    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end

    return nil
end

local function coordsFromTable(value)
    if not value then return nil end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    if not x or not y or not z then return nil end

    return {
        x = x,
        y = y,
        z = z,
        heading = tonumber(value.heading or value.w or value[4]) or 0.0
    }
end

local function normalizeSpawnCoords(value)
    return coordsFromTable(decodeJson(value))
end

local function normalizeInteractData(value)
    value = decodeJson(value)
    if not value then return nil end

    if value.coords or value.position or value.rotation or value.model or value.mode == 'dui' then
        local coords = coordsFromTable(value.coords or value.position or value)
        if not coords then return nil end

        return {
            mode = 'dui',
            type = 'prop',
            model = tonumber(value.model),
            modelName = value.modelName,
            coords = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            },
            rotation = value.rotation,
            heading = tonumber(value.heading or coords.heading) or 0.0
        }
    end

    local coords = coordsFromTable(value)
    if not coords then return nil end

    return {
        mode = 'dui',
        type = 'prop',
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        heading = coords.heading or 0.0
    }
end

local function getInteractCoords(interactData)
    local interact = normalizeInteractData(interactData)
    return interact and interact.coords or nil
end

local function getRawPlayerData()
    if GetResourceState('qbx_core') == 'started' then
        local ok, data = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)
        if ok and data then return data end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, data = pcall(function()
            return exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        end)
        if ok and data then return data end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, data = pcall(function()
            return exports['es_extended']:getSharedObject().PlayerData
        end)
        if ok and data then return data end
    end

    return {}
end

local function getPlayerAccessData()
    local raw = getRawPlayerData()
    local access = {
        jobName = nil,
        jobGrade = 0,
        gangName = nil,
        gangGrade = 0,
        citizenid = raw.citizenid or raw.citizenId or raw.identifier,
        sourceId = tostring(GetPlayerServerId(PlayerId()))
    }

    if pr_lib.framework and pr_lib.framework.GetJobInfo then
        local ok, job = pcall(pr_lib.framework.GetJobInfo)
        if ok and job then
            access.jobName = job.jobName or job.name
            access.jobGrade = tonumber(job.grade or job.level) or 0
        end
    end

    if raw.job then
        access.jobName = access.jobName or raw.job.name
        if type(raw.job.grade) == 'table' then
            access.jobGrade = tonumber(raw.job.grade.level or raw.job.grade.grade) or access.jobGrade
        else
            access.jobGrade = tonumber(raw.job.grade) or access.jobGrade
        end
    end

    if raw.gang then
        access.gangName = raw.gang.name
        if type(raw.gang.grade) == 'table' then
            access.gangGrade = tonumber(raw.gang.grade.level or raw.gang.grade.grade) or 0
        else
            access.gangGrade = tonumber(raw.gang.grade) or 0
        end
    end

    return access
end

local function cleanAccessValue(value)
    if value == nil then return nil end

    value = tostring(value)
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    local lowerValue = value:lower()
    if value == '' or lowerValue == 'none' or lowerValue == 'null' then return nil end

    return value
end

local function normalizeAccessType(accessType)
    accessType = cleanAccessValue(accessType)
    if not accessType then return 'public' end

    accessType = accessType:lower()
    accessType = accessType:gsub("%s+", "_"):gsub("%-", "_")

    local aliases = {
        public = 'public',
        publico = 'public',
        livre = 'public',
        job = 'job',
        emprego = 'job',
        gang = 'job',
        gangue = 'job',
        group = 'job',
        grupo = 'job',
        citizenid = 'citizenid',
        citizen_id = 'citizenid',
        cid = 'citizenid',
        player = 'citizenid',
        player_id = 'citizenid',
        password = 'password',
        senha = 'password',
        keycard = 'keycard',
        card = 'keycard',
        cartao = 'keycard',
        cartao_acesso = 'keycard',
        access_card = 'keycard',
        job_keycard = 'job_keycard',
        job_card = 'job_keycard',
        emprego_cartao = 'job_keycard',
        gang_keycard = 'job_keycard',
        gang_card = 'job_keycard',
        grupo_cartao = 'job_keycard',
        job_password = 'job_password',
        job_senha = 'job_password',
        emprego_senha = 'job_password',
        gang_password = 'job_password',
        gang_senha = 'job_password',
        grupo_senha = 'job_password',
        job_citizenid = 'job_citizenid',
        job_player_id = 'job_citizenid',
        emprego_player_id = 'job_citizenid',
        grupo_player_id = 'job_citizenid'
    }

    return aliases[accessType] or accessType
end

local function metadataMatches(metadata, accessKey)
    if not accessKey or accessKey == '' then return false end
    if type(metadata) ~= 'table' then return false end

    local expected = tostring(accessKey)
    return tostring(metadata.access_key or '') == expected
        or tostring(metadata.accessKey or '') == expected
        or tostring(metadata.acesso or '') == expected
        or tostring(metadata.access or '') == expected
end

local function getConfiguredKeycardItems(itemName)
    if itemName and itemName ~= '' then return { itemName } end

    local items = {}
    local list = PR.ItemList or {}
    for i = 1, #list do
        local value = list[i]
        if type(value) == 'table' and value.item then
            items[#items + 1] = value.item
        elseif type(value) == 'string' then
            items[#items + 1] = value
        end
    end

    if #items == 0 then
        for itemName, value in pairs(list) do
            if type(value) == 'table' then
                items[#items + 1] = value.item or value.name or itemName
            elseif type(value) == 'string' then
                items[#items + 1] = value
            end
        end
    end

    if #items == 0 then
        items[1] = PR.keycardItem or 'elevator_card'
    end

    return items
end

local function itemNameMatches(item, allowedItems)
    if not item then return false end
    local itemName = item.name or item.item

    for i = 1, #allowedItems do
        if itemName == allowedItems[i] then return true end
    end

    return false
end

local function hasKeycard(accessKey, itemName)
    accessKey = cleanAccessValue(accessKey)
    if not accessKey then return false end

    local allowedItems = getConfiguredKeycardItems(itemName)
    local metadataVariants = {
        { acesso = accessKey },
        { access_key = accessKey },
        { accessKey = accessKey },
        { access = accessKey }
    }
    local inventory = pr_lib.inventory or pr_lib.inventories

    if GetResourceState('ox_inventory') == 'started' then
        for i = 1, #allowedItems do
            for j = 1, #metadataVariants do
                local okCount, count = pcall(function()
                    return exports.ox_inventory:Search('count', allowedItems[i], metadataVariants[j])
                end)
                if okCount and tonumber(count) and tonumber(count) > 0 then return true end

                local okSlots, slots = pcall(function()
                    return exports.ox_inventory:Search('slots', allowedItems[i], metadataVariants[j])
                end)
                if okSlots and type(slots) == 'table' then
                    for _, item in pairs(slots) do
                        if metadataMatches(item.metadata or item.info, accessKey) then
                            return true
                        end
                    end
                end
            end

            local okSlots, slots = pcall(function()
                return exports.ox_inventory:Search('slots', allowedItems[i])
            end)
            if okSlots and type(slots) == 'table' then
                for _, item in pairs(slots) do
                    if metadataMatches(item.metadata or item.info, accessKey) then
                        return true
                    end
                end
            end
        end
    end

    if not inventory then return false end

    if inventory.GetItemCount then
        for i = 1, #allowedItems do
            for j = 1, #metadataVariants do
                local ok, count = pcall(inventory.GetItemCount, allowedItems[i], metadataVariants[j], true)
                if ok and tonumber(count) and tonumber(count) > 0 then return true end
            end
        end
    end

    if inventory.GetSlotWithItem then
        for i = 1, #allowedItems do
            for j = 1, #metadataVariants do
                local ok, slot = pcall(inventory.GetSlotWithItem, allowedItems[i], metadataVariants[j], true)
                if ok and slot and metadataMatches(slot.metadata or slot.info, accessKey) then return true end
            end
        end
    end

    if inventory.Search then
        for i = 1, #allowedItems do
            local ok, slots = pcall(inventory.Search, 'slots', allowedItems[i], { access_key = accessKey })
            if ok and slots then
                if type(slots) == 'table' then
                    for _, item in pairs(slots) do
                        if metadataMatches(item.metadata or item.info, accessKey) then
                            return true
                        end
                    end
                elseif slots == true then
                    return true
                end
            end
        end
    end

    if inventory.GetPlayerItems then
        local ok, items = pcall(inventory.GetPlayerItems)
        if ok and type(items) == 'table' then
            for _, item in pairs(items) do
                if item and itemNameMatches(item, allowedItems) and metadataMatches(item.metadata or item.info, accessKey) then
                    return true
                end
            end
        end
    end

    return false
end

local function hasJobAccess(accessData, access)
    local requiredGrade = tonumber(accessData.job_grade or accessData.access_job_grade) or 0
    local jobName = cleanAccessValue(accessData.job or accessData.access_job)
    return jobName and jobName ~= ''
        and access.jobName == jobName
        and (tonumber(access.jobGrade) or 0) >= requiredGrade
end

local function hasGangAccess(accessData, access)
    local requiredGrade = tonumber(accessData.job_grade or accessData.access_job_grade) or 0
    local gangName = cleanAccessValue(accessData.job or accessData.access_job)
    return gangName and gangName ~= ''
        and access.gangName == gangName
        and (tonumber(access.gangGrade) or 0) >= requiredGrade
end

local function hasGroupAccess(accessData, access)
    return hasJobAccess(accessData, access) or hasGangAccess(accessData, access)
end

local function getFloorAccessData(elevator, floor)
    local hasFloorAccess = floor and (
        floor.access_type ~= nil
        or floor.access_job ~= nil
        or floor.access_password ~= nil
        or floor.access_key ~= nil
        or floor.access_citizenid ~= nil
    )

    local accessType = hasFloorAccess and floor.access_type or elevator.type
    accessType = normalizeAccessType(accessType)

    return {
        type = accessType,
        job = cleanAccessValue(hasFloorAccess and floor.access_job or elevator.job),
        job_grade = hasFloorAccess and floor.access_job_grade or elevator.job_grade,
        password = cleanAccessValue(hasFloorAccess and floor.access_password or elevator.password),
        access_key = cleanAccessValue(hasFloorAccess and floor.access_key or elevator.access_key),
        access_item = cleanAccessValue(hasFloorAccess and floor.access_item or nil),
        citizenid = cleanAccessValue(hasFloorAccess and floor.access_citizenid or elevator.citizenid)
    }
end

local function checkFloorAccess(elevator, floor)
    local accessData = getFloorAccessData(elevator, floor)
    local accessType = normalizeAccessType(accessData.type)
    local access = getPlayerAccessData()

    if accessType == 'public' then
        return true, false, nil, nil
    end

    if accessType == 'job' or accessType == 'gang' then
        return hasGroupAccess(accessData, access), false, lang('menu.error_job_required'), nil
    end

    if accessType == 'citizenid' then
        local allowed = accessData.citizenid and (access.citizenid == accessData.citizenid or access.sourceId == accessData.citizenid)
        return allowed, false, lang('menu.error_citizenid_required'), nil
    end

    if accessType == 'keycard' then
        return hasKeycard(accessData.access_key, accessData.access_item), false, lang('menu.error_keycard_required'), nil
    end

    if accessType == 'job_keycard' then
        return hasGroupAccess(accessData, access) and hasKeycard(accessData.access_key, accessData.access_item), false, lang('menu.error_keycard_required'), nil
    end

    if accessType == 'password' then
        return accessData.password and accessData.password ~= '', true, lang('menu.error_password_required'), accessData.password
    end

    if accessType == 'job_password' then
        return hasGroupAccess(accessData, access) and accessData.password and accessData.password ~= '', true, lang('menu.error_password_required'), accessData.password
    end

    if accessType == 'job_citizenid' then
        local citizenAllowed = accessData.citizenid and (access.citizenid == accessData.citizenid or access.sourceId == accessData.citizenid)
        return hasGroupAccess(accessData, access) and citizenAllowed, false, lang('menu.error_citizenid_required'), nil
    end

    return false, false, lang('menu.error_select_elevator'), nil
end

local function waitForElevator()
    local duration = PR.elevatorWaitTime or 3000
    if pr_lib and pr_lib.progressBar then
        return pr_lib.progressBar({
            duration = duration,
            label = lang('menu.waiting_elevator'),
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true
            },
            anim = {
                dict = 'anim@apt_trans@elevator',
                clip = 'elev_1',
                flag = 16
            }
        })
    end

    Wait(duration)
    return true
end

local function teleportToFloor(floor)
    local coords = normalizeSpawnCoords(floor.coords)
    if not coords then
        runtimeNotify(lang('menu.error_invalid_coords'), 'error')
        return
    end

    local ped = PlayerPedId()
    if not waitForElevator() then return end

    DoScreenFadeOut(500)
    Wait(650)

    local vehicle = nil
    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
    end

    local entity = vehicle and vehicle ~= 0 and vehicle or ped
    SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(entity, coords.heading or 0.0)

    Wait(650)
    DoScreenFadeIn(600)
end

local function normalizeFloorCode(value)
    local code = tostring(value or ''):upper()
    code = code:gsub("%s+", "")
    return code
end

local function findFloorByCode(elevator, value)
    local requestedCode = normalizeFloorCode(value)
    if requestedCode == '' then return nil, requestedCode end

    local floors = elevator.floors or {}
    for i = 1, #floors do
        local floor = floors[i]
        local nameCode = normalizeFloorCode(floor.name)
        local orderCode = normalizeFloorCode(floor.floor)

        if requestedCode == nameCode or requestedCode == orderCode then
            return floor, requestedCode
        end
    end

    return nil, requestedCode
end

local function openFloorInputKeypad(elevator, currentFloor, prop)
    if not elevator.floors or #elevator.floors == 0 then
        runtimeNotify(lang('menu.no_floors'), 'error')
        return
    end

    if not prop or prop == 0 or not DoesEntityExist(prop) or type(OpenKeypadEntity) ~= 'function' then
        runtimeNotify(lang('menu.error_dui_unavailable'), 'error')
        return
    end

    local targetFloor, accessResult
    OpenKeypadEntity(prop, nil, {
        acceptAnyInput = true,
        prompt = lang('keypad.floor'),
        notify = false,
        validateInput = function(_, confirmedCode)
            local normalizedCode
            targetFloor, normalizedCode = findFloorByCode(elevator, confirmedCode)
            if not targetFloor then
                runtimeNotify((lang('menu.floor_not_found')):format(normalizedCode), 'error')
                return false, lang('keypad.invalid_floor')
            end

            if currentFloor and targetFloor.id == currentFloor.id then
                runtimeNotify(lang('menu.floor_current'), 'inform')
                return false, lang('keypad.current_floor')
            end

            accessResult = pr_lib.callback.await('pr_elevator:server:checkFloorAccess', false, targetFloor.id)
            if not accessResult then
                runtimeNotify(lang('menu.error_select_elevator'), 'error')
                return false, lang('keypad.error')
            end

            if accessResult.needsPassword then return true, lang('keypad.password') end
            if not accessResult.allowed then
                runtimeNotify(accessResult.message or lang('menu.error_select_elevator'), 'error')
                return false, lang('keypad.denied')
            end
            return true
        end,
        onSuccess = function()
            if accessResult.needsPassword then
                CreateThread(function()
                    Wait(350)
                    OpenKeypadEntity(prop, nil, {
                        acceptAnyInput = true,
                        prompt = lang('menu.password'),
                        notify = false,
                        validateInput = function(_, confirmedPassword)
                            local passwordResult = pr_lib.callback.await('pr_elevator:server:checkFloorAccess', false, targetFloor.id, confirmedPassword)
                            if not passwordResult or not passwordResult.allowed then
                                runtimeNotify(passwordResult and passwordResult.message or (lang('menu.invalid_password')), 'error')
                                return false, passwordResult and lang('keypad.invalid_password') or lang('keypad.error')
                            end

                            return true
                        end,
                        onSuccess = function()
                            teleportToFloor(targetFloor)
                        end
                    })
                end)
                return
            end

            teleportToFloor(targetFloor)
        end
    })
end

local function requestElevator(elevator, floor, prop)
    openFloorInputKeypad(elevator, floor, prop)
end

local function clearRenderedKeypads()
    for i = 1, #renderedKeypads do
        local entry = renderedKeypads[i]
        if entry.prop and DoesEntityExist(entry.prop) then
            if type(DeleteKeypad) == 'function' then
                DeleteKeypad(entry.prop)
            else
                if shouldUsePrTarget() then
                    if GetResourceState('pr_bridge') == 'started' then
                        exports.pr_bridge:removeLocalEntity(entry.prop, 'keypad_interaction')
                    end
                end
                if shouldUseInteract() then
                    if GetResourceState('pr_bridge') == 'started' then
                        exports.pr_bridge:RemoveLocalEntityInteraction(entry.prop, 'keypad_interact_' .. entry.prop)
                    end
                end
                DeleteEntity(entry.prop)
            end
        end
    end

    renderedKeypads = {}
end

local function renderFloorKeypad(elevator, floor)
    local interact = normalizeInteractData(floor.interact_coords)
    if not interact then
        local legacyCoords = normalizeSpawnCoords(floor.coords)
        if not legacyCoords then
            runtimeDebug((lang('debug.runtime_missing_coords')):format(tostring(floor.id), tostring(elevator.id)))
            return
        end

        interact = {
            mode = 'dui',
            type = 'prop',
            coords = {
                x = legacyCoords.x,
                y = legacyCoords.y,
                z = legacyCoords.z
            },
            heading = legacyCoords.heading or 0.0
        }
        runtimeDebug((lang('debug.runtime_legacy_coords')):format(tostring(floor.id), tostring(elevator.id)))
    end
    if type(CreateKeypadFromInteract) ~= 'function' then
        runtimeDebug(lang('debug.runtime_dui_unavailable'))
        return
    end

    local currentFloorName = floor.name or floor.floor or '?'
    local floorDistance = tonumber(PR and PR.KeypadInteractDistance) or 2.0
    local interactionName = ('pr_elevator_%s_%s'):format(
        tostring(elevator.id or 'elevator'),
        tostring(floor.id or floor.floor or currentFloorName)
    )

    local prop = CreateKeypadFromInteract(interact, nil, {
        name = interactionName,
        label = (lang('menu.runtime_interaction')):format(elevator.name or elevator.id, currentFloorName),
        distance = floorDistance,
        targetDistance = floorDistance,
        interactDistance = floorDistance,
        interactDrawDistance = math.max(5.0, floorDistance + 1.0),
        onSelect = function(data)
            requestElevator(elevator, floor, data.entity)
        end
    })

    if not prop then
        runtimeDebug((lang('debug.runtime_prop_failed')):format(tostring(floor.id), tostring(elevator.id)))
        return
    end

    renderedKeypads[#renderedKeypads + 1] = {
        prop = prop,
        elevator = elevator,
        floor = floor,
        coords = interact.coords,
        hasTarget = type(HasKeypadTarget) == 'function' and HasKeypadTarget(prop) or hasConfiguredTargetStarted()
    }
end

local function refreshRuntimeElevators()
    if refreshInProgress then refreshRequested=true;return end
    refreshInProgress = true

    clearRenderedKeypads()
    runtimeElevators = {}
    runtimeDebug(lang('debug.runtime_reload'))

    local duiTimeout = GetGameTimer() + 5000
    while type(CreateKeypadFromInteract) ~= 'function' and GetGameTimer() < duiTimeout do
        Wait(100)
    end

    local elevators = pr_lib.callback.await('pr_elevator:server:getElevators') or {}
    for i = 1, #elevators do
        local elevator = elevators[i]
        elevator.floors = pr_lib.callback.await('pr_elevator:server:getFloors', false, elevator.id) or {}
        runtimeElevators[#runtimeElevators + 1] = elevator

        for j = 1, #elevator.floors do
            renderFloorKeypad(elevator, elevator.floors[j])
        end
    end

    runtimeDebug((lang('debug.runtime_count')):format(tostring(#runtimeElevators), tostring(#renderedKeypads)))
    refreshInProgress = false
    if refreshRequested then
        refreshRequested=false
        CreateThread(refreshRuntimeElevators)
    end
end

local function startFallbackInteractionThread()
    CreateThread(function()
        while true do
            local sleep = 750

            if #renderedKeypads > 0 then
                local targetStarted = hasConfiguredTargetStarted()
                local ped = PlayerPedId()
                local playerCoords = GetEntityCoords(ped)
                local nearest = nil
                local nearestDistance = 9999.0

                for i = 1, #renderedKeypads do
                    local entry = renderedKeypads[i]
                    if entry.coords and (not targetStarted or not entry.hasTarget) then
                        local distance = #(playerCoords - vector3(entry.coords.x, entry.coords.y, entry.coords.z))
                        local drawDistance = PR.Marker and PR.Marker.DrawDistance or 12.0

                        if distance <= drawDistance then
                            local color = PR.Marker and PR.Marker.Color or { r = 255, g = 255, b = 255, a = 200 }
                            local scale = PR.Marker and PR.Marker.Scale or vector3(0.3, 0.3, 0.2)
                            DrawMarker(PR.Marker and PR.Marker.Type or 2, entry.coords.x, entry.coords.y, entry.coords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale.x, scale.y, scale.z, color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)
                            sleep = 0
                        end

                        if distance < nearestDistance then
                            nearest = entry
                            nearestDistance = distance
                        end
                    end
                end

                if nearest and nearestDistance <= (tonumber(PR and PR.KeypadInteractDistance) or 2.0) then
                    sleep = 0
                    if not textUiVisible then
                        pr_lib.showTextUI('[E] ' .. lang('menu.title'))
                        textUiVisible = true
                    end

                    if IsControlJustReleased(0, 38) then
                        if type(InteractWithKeypadEntity) == 'function' then
                            InteractWithKeypadEntity(nearest.prop)
                        else
                            requestElevator(nearest.elevator, nearest.floor, nearest.prop)
                        end
                    end
                elseif textUiVisible then
                    pr_lib.hideTextUI()
                    textUiVisible = false
                end
            elseif textUiVisible then
                pr_lib.hideTextUI()
                textUiVisible = false
            end

            Wait(sleep)
        end
    end)
end

RegisterNetEvent('pr_elevator:client:refreshElevators', function()
    CreateThread(function()
        Wait(500)
        refreshRuntimeElevators()
    end)
end)

local function scheduleInitialRefresh()
    CreateThread(function()
        Wait(3000)
        refreshRuntimeElevators()
    end)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        scheduleInitialRefresh()
        return
    end

    if resource == 'pr_bridge' then
        TriggerEvent('pr_elevator:client:refreshElevators')
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if textUiVisible then
        pr_lib.hideTextUI()
        textUiVisible = false
    end

    clearRenderedKeypads()
end)

RegisterCommand('prelevator_refresh', function()
    TriggerEvent('pr_elevator:client:refreshElevators')
end, false)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('pr_elevator:client:refreshElevators')
end)

RegisterNetEvent('qbx_core:client:playerLoggedIn', function()
    TriggerEvent('pr_elevator:client:refreshElevators')
end)

startFallbackInteractionThread()
