local lang = pr_lib.locale()
local DUI_BRIDGE_REVISION = '2026-10-03-server-validation'
print(lang('debug.dui_revision', DUI_BRIDGE_REVISION))

local txReplaceDict, txReplaceName = 'ch_prop_casino_keypads', 'prop_ld_keypad'
local propHash = joaat('ch_prop_casino_keypad_01')
local keypadHandle = nil
local keypadCam = nil
local duiHandle = nil
local prevButtonID = -1
local codeInput = ''
local passcode = ''
local buttonThreshold = 2.5
local maxCodeLength = 8
local notifyKeypadActions = true
local keypadContexts = {}
local activeKeypadContext = nil
local keypadTargetNames = {}
local keypadInteractIds = {}
local keypadRegisteredTargets = {}
local keypadInteractionBusy = false
local lastKeypadDisplay = lang('keypad.prompt')
local lastKeypadVisible = true
local duiPageReady = false
local activeKeypadEntity = nil
local duiPreviewActive = false
local confirmationBusy = false
local keypadSession = 0

local function GetInteractionMode()
    return tostring(PR and PR.Target or 'pr_bridge'):lower()
end

local function ShouldUsePrTarget()
    local mode = GetInteractionMode()
    return mode == 'pr_bridge' or mode == 'target' or mode == 'both' or mode == 'all'
end

local function ShouldUseInteract()
    local mode = GetInteractionMode()
    return mode == 'interact' or mode == 'both' or mode == 'all'
end

local function GetKeypadInteractOffset(options)
    local offset = options and options.interactOffset
    if not offset and PR then
        offset = PR.KeypadInteractOffset or PR.InteractOffset
    end

    if offset then
        local x = tonumber(offset.x or offset[1]) or 0.0
        local y = tonumber(offset.y or offset[2]) or 0.08
        local z = tonumber(offset.z or offset[3]) or 0.03
        return vector3(x, y, z)
    end

    return vector3(0.0, -0.18, 0.03)
end

local function DecodeJson(value)
    if type(value) ~= 'string' then return value end

    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end

    return nil
end

local function GetCoordsTable(value)
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

local function GetRotationTable(value)
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

local function NormalizeKeypadPlacement(x, y, z, heading, placement)
    local data = nil
    if placement ~= nil then
        data = DecodeJson(placement)
    elseif type(x) == 'table' or type(x) == 'string' then
        data = DecodeJson(x)
    end

    if type(data) == 'table' then
        local rawCoords = data.coords or data.position or data
        local coords = GetCoordsTable(rawCoords)
        if not coords then return nil end

        local rotation = GetRotationTable(data.rotation or data.rot)
        local resolvedHeading = tonumber(data.heading or rawCoords.heading or rawCoords.w or rawCoords[4])
            or (rotation and rotation.z)
            or 0.0

        return {
            coords = coords,
            rotation = rotation,
            heading = resolvedHeading,
            model = tonumber(data.model) or (data.modelName and joaat(data.modelName)) or propHash
        }
    end

    local coords = GetCoordsTable({ x = x, y = y, z = z })
    if not coords then return nil end

    return {
        coords = coords,
        heading = tonumber(heading) or 0.0,
        model = propHash
    }
end

local function ApplyKeypadTransform(prop, placement)
    if placement.rotation then
        SetEntityRotation(
            prop,
            placement.rotation.x or 0.0,
            placement.rotation.y or 0.0,
            placement.rotation.z or placement.heading or 0.0,
            2,
            true
        )
    else
        SetEntityHeading(prop, placement.heading or 0.0)
    end
end

local inputButtons = {
    [1] = '1',
    [2] = '2',
    [3] = '3',
    [4] = '4',
    [5] = '5',
    [6] = '6',
    [7] = '7',
    [8] = '8',
    [9] = '9',
    [10] = 'S',
    [11] = '0',
    [12] = '#'
}

local validInputKeys = {}

for _, key in pairs(inputButtons) do
    validInputKeys[key] = true
end

local randomCodeKeys = {
    '1', '2', '3', '4', '5', '6', '7', '8', '9', 'S', '0', '#'
}

-- Define button rotations (relative to initial rotation)
local buttonCamRots = {
    [1] = vec3(-3.52, 0.0, 8.06),
    [2] = vec3(-3.52, 0.0, 2.70),
    [3] = vec3(-3.52, 0.0, -2.58),
    [4] = vec3(-8.56, 0.0, 8.06),
    [5] = vec3(-8.56, 0.0, 2.58),
    [6] = vec3(-8.56, 0.0, -2.64),
    [7] = vec3(-13.48, 0.0, 8.0),
    [8] = vec3(-13.51, 0.0, 2.77),
    [9] = vec3(-13.51, 0.0, -2.7),
    [10] = vec3(-18.0, 0.0, 8.06), -- S
    [11] = vec3(-18.1, 0.0, 2.7), -- 0
    [12] = vec3(-18.2, 0.0, -2.58), -- #
    [13] = vec3(-3.52, 0.0, -7.86), -- Red / cancel
    [14] = vec3(-8.56, 0.0, -7.86), -- Green / confirm
    [15] = vec3(-13.51, 0.0, -7.86), -- Blue / unused
    [16] = vec3(-18.1, 0.0, -7.86) -- Yellow / correct
}

local function GeneratePasscode(length)
    local code = ''

    for _ = 1, length or maxCodeLength do
        code = code .. randomCodeKeys[math.random(#randomCodeKeys)]
    end

    return code
end

local function SetKeypadPasscode(code)
    local normalized = ''

    for key in tostring(code or GeneratePasscode(maxCodeLength)):upper():gmatch('.') do
        if validInputKeys[key] and #normalized < maxCodeLength then
            normalized = normalized .. key
        end
    end

    passcode = normalized ~= '' and normalized or GeneratePasscode(maxCodeLength)
end

local function SetKeypadDisplay(value)
    lastKeypadDisplay = tostring(value or '')
    if duiHandle then
        duiHandle:sendMessage({
            action = "DISPLAY",
            value = lastKeypadDisplay
        })
    end
end

local function SetKeypadVisible(value)
    lastKeypadVisible = value == true
    if duiHandle then
        duiHandle:sendMessage({
            action = "KEYPAD",
            value = lastKeypadVisible
        })
    end
end

local function SyncKeypadDui(retries)
    if not duiHandle then return end

    retries = retries or 1
    CreateThread(function()
        for i = 1, retries do
            duiHandle:sendMessage({
                action = "KEYPAD",
                value = lastKeypadVisible
            })
            duiHandle:sendMessage({
                action = "DISPLAY",
                value = lastKeypadDisplay
            })
            Wait(150)
        end
    end)
end

local function GetKeypadPrompt(context)
    return (context and context.prompt) or lang('keypad.prompt')
end

RegisterNUICallback('keypadDuiReady', function(_, cb)
    duiPageReady = true
    cb({ok=true})
    -- The DOM may be ready after native IsDuiAvailable and the initial retries.
    SyncKeypadDui(2)
end)

RegisterCommand('prelevator_dui_status', function()
    print((lang('debug.dui_status')):format(
        tostring(duiHandle~=nil), tostring(duiPageReady), tostring(duiHandle and duiHandle.active),
        txReplaceDict, txReplaceName, tostring(duiHandle and duiHandle.url)))
    local entity = activeKeypadEntity
    local model = entity and DoesEntityExist(entity) and GetEntityModel(entity) or nil
    local available = duiHandle and duiHandle.duiObject and IsDuiAvailable(duiHandle.duiObject) or false
    print((lang('debug.dui_native')):format(
        tostring(available), tostring(model), tostring(propHash),
        tostring(duiHandle and duiHandle.txd), tostring(duiHandle and duiHandle.txn),
        tostring(duiHandle and duiHandle.runtimeTxd), tostring(duiHandle and duiHandle.txdObject)))
end, false)

-- Preview the same runtime texture without changing input or saved placement.
RegisterCommand('prelevator_dui_preview', function()
    if duiPreviewActive then return end
    if not duiHandle or not duiHandle.active then
        print(lang('debug.preview_open'))
        return
    end
    local instance = duiHandle
    local ok, err = instance:startSprite({x=0.15, y=0.5, width=0.2, height=0.7})
    if not ok then
        print((lang('debug.preview_failed')):format(tostring(err)))
        return
    end
    duiPreviewActive = true
    print(lang('debug.preview_started'))
    CreateThread(function()
        Wait(10000)
        if instance.active then instance:stopSprite() end
        duiPreviewActive = false
    end)
end, false)

local function NotifyKeypad(description, notifyType)
    if not notifyKeypadActions then return end
    if activeKeypadContext and activeKeypadContext.notify == false then return end

    pr_lib.notify.Notify({
        title = lang('menu.keypad'),
        description = description,
        type = notifyType or 'inform',
        duration = 1500
    })
end

local function RemoveKeypadTarget(prop)
    if prop and DoesEntityExist(prop) then
        if keypadTargetNames[prop] and GetResourceState('pr_bridge') == 'started' then
            exports.pr_bridge:removeLocalEntity(prop, keypadTargetNames[prop])
            keypadTargetNames[prop] = nil
        end
        if GetResourceState('pr_bridge') == 'started' then
            local interactId = keypadInteractIds[prop]
            if interactId then
                pcall(function()
                    exports.pr_bridge:RemoveInteraction(interactId)
                end)
                keypadInteractIds[prop] = nil
            end
        end
        keypadRegisteredTargets[prop] = nil
    end
end

function DeleteKeypad(prop)
    if prop and prop == activeKeypadEntity then ResetToDefaultCam() end
    if prop and DoesEntityExist(prop) then
        RemoveKeypadTarget(prop)
        keypadContexts[prop] = nil
        keypadRegisteredTargets[prop] = nil
        DeleteEntity(prop)
    end
end

local function SelectKeypad(prop, options, coords)
    local context = keypadContexts[prop] or options
    local data = { entity = prop, coords = coords }

    if context and type(context.onSelect) == 'function' then
        context.onSelect(data, context)
    elseif context and (context.code or context.onSuccess) then
        OpenKeypadEntity(prop, context and context.code, context)
    else
        TransitionToKeypadCam(prop, context)
    end
end

function InteractWithKeypadEntity(prop, options, coords)
    local context = keypadContexts[prop] or options or {}
    if not prop or prop == 0 or not DoesEntityExist(prop) then return end
    if keypadInteractionBusy then return end

    local streaming = pr_lib and pr_lib.fivem and pr_lib.fivem.streaming
    if not streaming or not streaming.playInteraction then
        SelectKeypad(prop, context, coords)
        return
    end

    keypadInteractionBusy = true
    CreateThread(function()
        local interactOffset = GetKeypadInteractOffset(context)
        local anim = context.anim or context.animation or (PR and PR.KeypadInteractionAnimation) or {
            dict = 'mp_common',
            clip = 'givetake1_a',
            duration = 900,
            flags = 49
        }

        local opened = false
        local ok = streaming.playInteraction({
            target = prop,
            type = 'object',
            anim = anim,
            position = {
                offset = vector3(interactOffset.x, interactOffset.y - 0.55, 0.0),
                moveTo = true,
                ground = true,
                faceTarget = true,
                arriveDistance = 0.05,
                maxDistance = 2.0,
                timeout = 3000
            },
            cleanup = {
                clearTasks = true
            },
            onFinish = function()
                opened = true
                SelectKeypad(prop, context, coords)
            end
        })

        if not ok and not opened then
            SelectKeypad(prop, context, coords)
        end

        keypadInteractionBusy = false
    end)
end

function CreateDUI()
    if duiHandle ~= nil then
        SyncKeypadDui(2)
        return duiHandle
    end

    duiPageReady = false
    local createdDui, createError = pr_lib.dui.create({
        id = 'pr_elevator_keypad',
        url = pr_lib.dui.nuiUrl('ui/ui.html?dui=1', GetCurrentResourceName()),
        width = 512,
        height = 1024,
        debug = false
    })

    if not createdDui then
        print((lang('debug.dui_create_failed')):format(tostring(createError)))
        return nil, createError
    end

    local replaced, replaceError = createdDui:replaceTexture({
        originalTxd = txReplaceDict,
        originalTxn = txReplaceName
    })

    if not replaced then
        createdDui:destroy()
        print((lang('debug.dui_replace_failed')):format(tostring(replaceError)))
        return nil, replaceError
    end

    duiHandle = createdDui
    Wait(500)   -- Sometimes webpage hasnt loaded, not generally an issue if the dui isnt created as soon as resource starts
    SetKeypadVisible(true)
    SetKeypadDisplay(GetKeypadPrompt())
    SyncKeypadDui(6)
    return duiHandle
end

function CreateKeypad(x, y, z, w, placementData, options)
    local placement = NormalizeKeypadPlacement(x, y, z, w, placementData)
    if not placement then return nil end
    options = options or {}

    local model = placement.model or propHash
    pr_lib.requestModel(model)
    local coords = placement.coords
    local prop = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    if not prop or prop == 0 then return nil end

    local interactionName = options.name and ('%s_%s'):format(options.name, prop) or ('keypad_interaction_%s'):format(prop)
    local configuredInteractionDistance = tonumber(options.interactDistance or options.targetDistance or (PR and PR.KeypadInteractDistance)) or 2.0
    local targetDistance = configuredInteractionDistance
    local interactDst = configuredInteractionDistance
    local interactDistance = tonumber(options.interactDrawDistance or options.drawDistance) or 5.0
    local interactOffset = GetKeypadInteractOffset(options)
    if interactDistance < interactDst then
        interactDistance = interactDst + 0.5
    end

    SetEntityAsMissionEntity(prop, true, true)
    ApplyKeypadTransform(prop, placement)
    FreezeEntityPosition(prop, true)
    keypadContexts[prop] = options

    if ShouldUsePrTarget() and GetResourceState('pr_bridge') == 'started' then
        keypadTargetNames[prop] = interactionName
        local oxRegistered = pcall(function()
            exports.pr_bridge:addLocalEntity(prop, {
                {
                    name = interactionName,
                    icon = options.icon or 'fas fa-hashtag',
                    label = options.label or lang('menu.interact_keypad'),
                    distance = targetDistance,
                    ignoreLos = PR.RespectWalls == false,
                    wallDetection = PR.RespectWalls ~= false,
                    onSelect = function(data)
                        InteractWithKeypadEntity(data.entity or prop, options, data.coords)
                    end
                }
            })
        end)
        if oxRegistered then
            keypadRegisteredTargets[prop] = true
        end
    end

    if ShouldUseInteract() and GetResourceState('pr_bridge') == 'started' then
        local interactOptions = {
            {
                name = interactionName,
                label = options.label or lang('menu.interact_keypad'),
                action = function(entity, actionCoords, args)
                    InteractWithKeypadEntity(entity or prop, options, actionCoords)
                end
            }
        }

        local localRegistered, returnedId = pcall(function()
            return exports.pr_bridge:AddLocalEntityInteraction({
                entity = prop,
                name = interactionName,
                distance = interactDistance,
                interactDst = interactDst,
                offset = interactOffset,
                ignoreLos = PR.RespectWalls == false,
                wallDetection = PR.RespectWalls ~= false,
                options = interactOptions
            })
        end)

        if localRegistered and returnedId then
            keypadInteractIds[prop] = returnedId
            keypadRegisteredTargets[prop] = true
        else
            local coordRegistered, coordId = pcall(function()
                local fallbackCoords = GetOffsetFromEntityInWorldCoords(prop, interactOffset.x, interactOffset.y, interactOffset.z)
                return exports.pr_bridge:AddInteraction({
                    name = interactionName,
                    coords = fallbackCoords,
                    distance = interactDistance,
                    interactDst = interactDst,
                    ignoreLos = PR.RespectWalls == false,
                    wallDetection = PR.RespectWalls ~= false,
                    options = interactOptions
                })
            end)

            if coordRegistered and coordId then
                keypadInteractIds[prop] = coordId
                keypadRegisteredTargets[prop] = true
            end
        end
    end
    return prop
end

function HasKeypadTarget(prop)
    return keypadRegisteredTargets[prop] == true
end

function CreateKeypadFromInteract(interactData, code, options)
    CreateDUI()
    options = options or {}
    if code then
        options.code = code
    end

    local prop = CreateKeypad(interactData, nil, nil, nil, nil, options)
    if not prop then return nil end

    if code then
        SetKeypadPasscode(code)
    end
    return prop, passcode
end

function OpenKeypadEntity(prop, code, context)
    if not prop or prop == 0 or not DoesEntityExist(prop) then return false end

    CreateDUI()
    context = context or keypadContexts[prop] or {}
    if code ~= nil then
        context.code = code
    end

    if not context.acceptAnyInput then
        SetKeypadPasscode(context.code)
    else
        passcode = ''
    end

    TransitionToKeypadCam(prop, context)
    return true
end

function CreateTestKeypad(code)
    CreateDUI()

    DeleteKeypad(keypadHandle)
    keypadHandle = nil

    local ped = pr_lib.cache.get('ped') or PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.45)
    local heading = GetEntityHeading(ped)

    keypadHandle = CreateKeypad(coords.x, coords.y, coords.z, heading)
    SetKeypadPasscode(code)
    print(lang('debug.test_code'))

    return keypadHandle, passcode
end

function CalculateInitialCameraRotation(keypadHeading)
    local heading = (keypadHeading + 360.0) % 360.0
    return vec3(0.0, 0.0, heading)
end

function TransitionToKeypadCam(prop, context)
    keypadSession = keypadSession + 1
    local session = keypadSession
    confirmationBusy = false
    activeKeypadEntity = prop
    activeKeypadContext = context or keypadContexts[prop]
    codeInput = ''
    SetKeypadVisible(true)
    SetKeypadDisplay(GetKeypadPrompt(activeKeypadContext))
    SyncKeypadDui(4)

    local keypadCoords = GetEntityCoords(prop)
    local camOffset = GetOffsetFromEntityInWorldCoords(prop, 0.0, -0.25, 0.0)
    keypadCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(keypadCam, camOffset.x, camOffset.y, camOffset.z)
    local initialRot = CalculateInitialCameraRotation(GetEntityHeading(prop))
    SetCamRot(keypadCam, initialRot.x, initialRot.y, initialRot.z, 2)
    SetCamActive(keypadCam, true)
    RenderScriptCams(true, true, 1000, true, true)
    
    local ped = pr_lib.cache.get('ped') or PlayerPedId()
    FreezeEntityPosition(ped, true)
    TriggerEvent('zoom:updateBlock', true)          -- <= Will be different per server, hide / disable what you want here
    TriggerEvent('hud:client:ToggleHUD', false)     -- ..................................................................

    CreateThread(function()
        Wait(1000)
        if session ~= keypadSession then return end
        SetKeypadVisible(true)
        -- Preserve CHECKING/INVALID/SUCCESS instead of restoring an older prompt.
        SyncKeypadDui(1)
        SendNUIMessage({
            action = 'MOUSE',
            value = true
        })
    end)

    local camRot = initialRot
    local btnLookingAt = -1

    -- Track the camera's rotation and determine which button is being looked at
    CreateThread(function()
        while session == keypadSession and DoesCamExist(keypadCam) and IsCamActive(keypadCam) do
            DisableAllControlActions(0)

            -- Get mouse input
            xMouse = GetDisabledControlNormal(0, 1) * 8.0
            yMouse = GetDisabledControlNormal(0, 2) * 8.0
            camRot = vector3(
                math.clamp(camRot.x - yMouse, initialRot.x - 22.0, initialRot.x + 15.0),
                camRot.y,
                math.clamp(camRot.z - xMouse, initialRot.z - 15.0, initialRot.z + 15.0) 
            )
            
            -- Update camera rotation
            SetCamRot(keypadCam, camRot.x, camRot.y, camRot.z, 2)

            -- Check which button the camera is looking at
            for buttonId, buttonRot in pairs(buttonCamRots) do
                if IsCameraLookingAtButton(camRot, buttonRot, initialRot) then
                    btnLookingAt = buttonId
                end
            end

            -- Highlight the button or clear highlight
            if btnLookingAt ~= -1 then 
                HighlightButton(btnLookingAt)
            else
                HighlightButton(0)
            end

            -- Handle click action
            if IsDisabledControlJustPressed(0, 24) and btnLookingAt > 0 then
                ClickButton(btnLookingAt)
            end

            -- Handle exit interaction
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                ResetToDefaultCam()
                break
            end

            btnLookingAt = -1
            Wait(0)
        end
    end)
end

function NormalizeAngle(angle)
    return ((angle + 180) % 360) - 180
end

function IsCameraLookingAtButton(camRot, buttonRot, initialRot)
    local relativeRot = vector3(
        NormalizeAngle(camRot.x - initialRot.x), 
        NormalizeAngle(camRot.y - initialRot.y), 
        NormalizeAngle(camRot.z - initialRot.z)
    )
    local deltaX = math.abs(relativeRot.x - buttonRot.x)
    local deltaY = math.abs(relativeRot.y - buttonRot.y)
    local deltaZ = math.abs(relativeRot.z - buttonRot.z)
    return deltaX <= buttonThreshold and deltaY <= buttonThreshold and deltaZ <= buttonThreshold
end

function math.clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

function ResetToDefaultCam()
    keypadSession = keypadSession + 1
    confirmationBusy = false
    if DoesCamExist(keypadCam) then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(keypadCam, false)
        keypadCam = nil
    end
    HighlightButton(0)
    local ped = pr_lib.cache.get('ped') or PlayerPedId()
    FreezeEntityPosition(ped, false)
    TriggerEvent('zoom:updateBlock', false)     -- <= Will be different per server, show / enable what you want here
    TriggerEvent('hud:client:ToggleHUD', true)  -- ..................................................................
    SendNUIMessage({
        action = 'MOUSE',
        value = false
    })
    codeInput = ''
    activeKeypadContext = nil
    if duiHandle then
        SetKeypadDisplay(GetKeypadPrompt())
    end
end

RegisterCommand('prelevator_dui_reset', function()
    ResetToDefaultCam()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    FreezeEntityPosition(PlayerPedId(), false)
    SendNUIMessage({
        action = 'KEYPAD',
        value = false
    })
    SendNUIMessage({
        action = 'MOUSE',
        value = false
    })
end, false)

function PlayKeypadSound(sType)
    local sounds = {
        [1] = { -- Key press
            name = "Press",
            ref = "DLC_SECURITY_BUTTON_PRESS_SOUNDS"
        },
        [2] = { -- Error
            name = "Hack_Fail",
            ref = "DLC_sum20_Business_Battle_AC_Sounds"
        },
        [3] = { -- Success
            name = "Keypad_Access",
            ref = "DLC_Security_Data_Leak_2_Sounds"
        }

    }
    local sid = GetSoundId()
    PlaySoundFrontend(sid, sounds[sType].name, sounds[sType].ref, 1)
    ReleaseSoundId(sid)
end

local function ConfirmCode()
    if confirmationBusy then return end
    local context = activeKeypadContext
    local confirmedCode = codeInput

    if confirmedCode == '' then
        PlayKeypadSound(2)
        SetKeypadDisplay(lang('keypad.empty'))
        NotifyKeypad(lang('keypad.enter_value'), 'error')
        return
    end

    if context and type(context.validateInput) == 'function' then
        confirmationBusy = true
        local session = keypadSession
        SetKeypadDisplay(lang('keypad.checking'))
        CreateThread(function()
            local ok, allowed, display = pcall(context.validateInput, context, confirmedCode)
            -- ESC, a removed keypad or another session invalidate late results.
            if session ~= keypadSession or activeKeypadContext ~= context then return end
            if not ok then
                print(lang('debug.validation_failed'))
                allowed, display = false, lang('keypad.error')
            end
            if allowed ~= true then
                codeInput = ''
                PlayKeypadSound(2)
                SetKeypadDisplay(display or lang('keypad.invalid'))
                confirmationBusy = false
                return
            end
            PlayKeypadSound(3)
            SetKeypadDisplay(display or lang('keypad.success'))
            Wait(750)
            if session ~= keypadSession or activeKeypadContext ~= context then return end
            ResetToDefaultCam()
            if type(context.onSuccess) == 'function' then context.onSuccess(context, confirmedCode) end
        end)
    elseif (context and context.acceptAnyInput) or confirmedCode == passcode then
        PlayKeypadSound(3)
        SetKeypadDisplay(lang('keypad.success'))
        if context and type(context.onSuccess) == 'function' then
            CreateThread(function()
                Wait(250)
                ResetToDefaultCam()
                context.onSuccess(context, confirmedCode)
            end)
        else
            NotifyKeypad(lang('keypad.confirmed'), 'success')
        end
    else
        codeInput = ''
        PlayKeypadSound(2)
        SetKeypadDisplay(lang('keypad.invalid'))
        NotifyKeypad(lang('keypad.invalid_code'), 'error')
    end
end

function ClickButton(buttonId)
    if confirmationBusy and buttonId ~= 13 then return end
    local input = inputButtons[buttonId]

    if input and #codeInput < maxCodeLength then
        PlayKeypadSound(1)
        codeInput = codeInput .. input
        SetKeypadDisplay(codeInput)
        NotifyKeypad(lang('keypad.key', input))
    elseif buttonId == 13 then -- Red / cancel and exit
        PlayKeypadSound(1)
        NotifyKeypad(lang('keypad.cancelled'), 'error')
        ResetToDefaultCam()
    elseif buttonId == 14 then -- Green / confirm
        PlayKeypadSound(1)
        ConfirmCode()
    elseif buttonId == 15 then -- Blue / unused
        PlayKeypadSound(1)
        NotifyKeypad(lang('keypad.blue_unused'))
    elseif buttonId == 16 then -- Yellow / correct
        PlayKeypadSound(1)
        codeInput = codeInput:sub(1, -2)
        SetKeypadDisplay(codeInput ~= '' and codeInput or GetKeypadPrompt(activeKeypadContext))
        NotifyKeypad(lang('keypad.corrected'))
    end
end

function HighlightButton(buttonId)
    if prevButtonID ~= buttonId and duiHandle then
        duiHandle:sendMessage({
            action = "BUTTON",
            value = buttonId
        })
        prevButtonID = buttonId
    end
end

RegisterCommand('createkeypad', function(source, args)

    CreateDUI()
    DeleteKeypad(keypadHandle)
    keypadHandle = CreateKeypad(212.12, 1168.74, 227.5, 283.88)
    SetKeypadPasscode(args[1])
    print(lang('debug.test_code'))
	
end, false)

RegisterCommand('testkeypad', function(source, args)
    CreateTestKeypad(args[1])
end, false)

exports('CreateDUI', CreateDUI)
exports('CreateKeypad', CreateKeypad)
exports('CreateKeypadFromInteract', CreateKeypadFromInteract)
exports('OpenKeypadEntity', OpenKeypadEntity)
exports('DeleteKeypad', DeleteKeypad)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if duiHandle and type(duiHandle.destroy) == 'function' then
        duiHandle:destroy()
        duiHandle = nil
    else
        RemoveReplaceTexture(txReplaceDict, txReplaceName)
    end

    DeleteKeypad(keypadHandle)
    ResetToDefaultCam()
end)
