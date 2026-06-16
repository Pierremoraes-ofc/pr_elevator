local lang = pr_lib.locale()

local runtimeElevators = {}
local renderedKeypads = {}
local textUiVisible = false
local refreshInProgress = false

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

    lib.notify({
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
        citizenid = raw.citizenid or raw.identifier
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

local function metadataMatches(metadata, accessKey)
    if not accessKey or accessKey == '' then return false end
    if type(metadata) ~= 'table' then return false end

    return metadata.access_key == accessKey
        or metadata.accessKey == accessKey
        or metadata.acesso == accessKey
        or metadata.access == accessKey
end

local function hasKeycard(accessKey)
    if not accessKey or accessKey == '' then return false end

    local itemName = PR.keycardItem or 'elevator_card'
    local inventory = pr_lib.inventory or pr_lib.inventories
    if not inventory then return false end

    if inventory.GetItemCount then
        local ok, count = pcall(inventory.GetItemCount, itemName, { access_key = accessKey }, true)
        if ok and tonumber(count) and tonumber(count) > 0 then return true end
    end

    if inventory.GetSlotWithItem then
        local ok, slot = pcall(inventory.GetSlotWithItem, itemName, { access_key = accessKey }, true)
        if ok and slot then return true end
    end

    if inventory.Search then
        local ok, slots = pcall(inventory.Search, 'slots', itemName, { access_key = accessKey })
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

    if inventory.GetPlayerItems then
        local ok, items = pcall(inventory.GetPlayerItems)
        if ok and type(items) == 'table' then
            for _, item in pairs(items) do
                if item and item.name == itemName and metadataMatches(item.metadata or item.info, accessKey) then
                    return true
                end
            end
        end
    end

    return false
end

local function hasJobAccess(elevator, access)
    local requiredGrade = tonumber(elevator.job_grade) or 0
    return elevator.job and elevator.job ~= ''
        and access.jobName == elevator.job
        and (tonumber(access.jobGrade) or 0) >= requiredGrade
end

local function hasGangAccess(elevator, access)
    local requiredGrade = tonumber(elevator.job_grade) or 0
    return elevator.job and elevator.job ~= ''
        and access.gangName == elevator.job
        and (tonumber(access.gangGrade) or 0) >= requiredGrade
end

local function hasGroupAccess(elevator, access)
    return hasJobAccess(elevator, access) or hasGangAccess(elevator, access)
end

local function checkElevatorAccess(elevator)
    local elevatorType = elevator.type or 'public'
    local access = getPlayerAccessData()

    if elevatorType == 'public' then
        return true, false
    end

    if elevatorType == 'job' then
        return hasJobAccess(elevator, access), false, lang('menu.error_job_required')
    end

    if elevatorType == 'gang' then
        return hasGangAccess(elevator, access), false, lang('menu.error_job_required')
    end

    if elevatorType == 'citizenid' then
        return elevator.citizenid and elevator.citizenid ~= '' and access.citizenid == elevator.citizenid, false, lang('menu.error_citizenid_required')
    end

    if elevatorType == 'keycard' then
        return hasKeycard(elevator.access_key), false, lang('menu.error_keycard_required')
    end

    if elevatorType == 'job_keycard' then
        return hasGroupAccess(elevator, access) and hasKeycard(elevator.access_key), false, lang('menu.error_keycard_required')
    end

    if elevatorType == 'password' then
        return elevator.password and elevator.password ~= '', true, lang('menu.error_password_required')
    end

    if elevatorType == 'job_password' then
        return hasGroupAccess(elevator, access) and elevator.password and elevator.password ~= '', true, lang('menu.error_password_required')
    end

    return false, false, lang('menu.error_select_elevator')
end

local function waitForElevator()
    local duration = PR.elevatorWaitTime or 3000
    if lib and lib.progressBar then
        return lib.progressBar({
            duration = duration,
            label = lang('menu.waiting_elevator') or 'Aguardando elevador...',
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
        runtimeNotify(lang('menu.error_dui_unavailable') or 'DUI indisponivel.', 'error')
        return
    end

    OpenKeypadEntity(prop, nil, {
        acceptAnyInput = true,
        prompt = 'ANDAR',
        notify = false,
        onSuccess = function(_, confirmedCode)
            local targetFloor, normalizedCode = findFloorByCode(elevator, confirmedCode)
            if not targetFloor then
                runtimeNotify((lang('menu.floor_not_found') or 'Andar "%s" nao encontrado.'):format(normalizedCode), 'error')
                return
            end

            if currentFloor and targetFloor.id == currentFloor.id then
                runtimeNotify(lang('menu.floor_current') or 'Voce ja esta neste andar.', 'inform')
                return
            end

            teleportToFloor(targetFloor)
        end
    })
end

local function requestElevator(elevator, floor, prop)
    local allowed, needsPassword, message = checkElevatorAccess(elevator)
    if not allowed then
        runtimeNotify(message or lang('menu.error_select_elevator'), 'error')
        return
    end

    if needsPassword then
        if not prop or prop == 0 or not DoesEntityExist(prop) or type(OpenKeypadEntity) ~= 'function' then
            runtimeNotify(lang('menu.error_dui_unavailable') or 'DUI indisponivel.', 'error')
            return
        end

        OpenKeypadEntity(prop, elevator.password, {
            prompt = lang('menu.password'),
            notify = false,
            onSuccess = function()
                CreateThread(function()
                    Wait(350)
                    openFloorInputKeypad(elevator, floor, prop)
                end)
            end
        })
        return
    end

    openFloorInputKeypad(elevator, floor, prop)
end

local function clearRenderedKeypads()
    for i = 1, #renderedKeypads do
        local entry = renderedKeypads[i]
        if entry.prop and DoesEntityExist(entry.prop) then
            if type(DeleteKeypad) == 'function' then
                DeleteKeypad(entry.prop)
            else
                if GetResourceState('ox_target') == 'started' then
                    exports.ox_target:removeLocalEntity(entry.prop, 'keypad_interaction')
                end
                if GetResourceState('interact') == 'started' then
                    exports.interact:RemoveLocalEntityInteraction(entry.prop, 'keypad_interact_' .. entry.prop)
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
            runtimeDebug(("andar id=%s elevador=%s sem interact_coords/coords validos; prop nao renderizado"):format(tostring(floor.id), tostring(elevator.id)))
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
        runtimeDebug(("andar id=%s elevador=%s usando coords legado como interacao"):format(tostring(floor.id), tostring(elevator.id)))
    end
    if type(CreateKeypadFromInteract) ~= 'function' then
        runtimeDebug("CreateKeypadFromInteract indisponivel; DUI ainda nao carregou")
        return
    end

    local prop = CreateKeypadFromInteract(interact, nil, {
        label = ('Elevador: %s'):format(elevator.name or elevator.id),
        onSelect = function(data)
            requestElevator(elevator, floor, data.entity)
        end
    })

    if not prop then
        runtimeDebug(("falha ao criar prop do andar id=%s elevador=%s"):format(tostring(floor.id), tostring(elevator.id)))
        return
    end

    renderedKeypads[#renderedKeypads + 1] = {
        prop = prop,
        elevator = elevator,
        floor = floor,
        coords = interact.coords,
        hasTarget = GetResourceState('ox_target') == 'started' or GetResourceState('interact') == 'started'
    }
end

local function refreshRuntimeElevators()
    if refreshInProgress then return end
    refreshInProgress = true

    clearRenderedKeypads()
    runtimeElevators = {}
    runtimeDebug("recarregando elevadores")

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

    runtimeDebug(("elevadores=%s props=%s"):format(tostring(#runtimeElevators), tostring(#renderedKeypads)))
    refreshInProgress = false
end

local function startFallbackInteractionThread()
    CreateThread(function()
        while true do
            local sleep = 750

            if #renderedKeypads > 0 then
                local targetStarted = GetResourceState('ox_target') == 'started' or GetResourceState('interact') == 'started'
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

                if nearest and nearestDistance <= (tonumber(nearest.floor.distance) or 2.0) then
                    sleep = 0
                    if not textUiVisible then
                        lib.showTextUI('[E] Elevador')
                        textUiVisible = true
                    end

                    if IsControlJustReleased(0, 38) then
                        requestElevator(nearest.elevator, nearest.floor, nearest.prop)
                    end
                elseif textUiVisible then
                    lib.hideTextUI()
                    textUiVisible = false
                end
            elseif textUiVisible then
                lib.hideTextUI()
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
    if resource ~= GetCurrentResourceName() then return end

    scheduleInitialRefresh()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if textUiVisible then
        lib.hideTextUI()
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
