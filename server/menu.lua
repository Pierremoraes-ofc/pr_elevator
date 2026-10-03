-- aqui servidor do sistema de menu para gerenciamento dos elevadores e andares
local lang = pr_lib.locale()

local function printLocaleDebug()
    local localeName = type(lang) == 'table' and type(lang.locale) == 'function' and lang:locale() or tostring(lang)
    local localeResource = type(lang) == 'table' and lang.resource or lang('debug.not_available')
    local localePath = type(lang) == 'table' and lang.path or lang('debug.not_available')
    local convarLocale = GetConvar('pr_bridge:locale', 'nil')
    -- O idioma resolvido pelo bridge e a fonte; nao depender de replicacao global.
    pr_lib.cache.set('pr_elevator:locale', localeName)
    local cachedLocale = pr_lib.cache.get('pr_elevator:locale', 'nil')

    print((lang('debug.locale_server')):format(
        tostring(localeName),
        tostring(convarLocale),
        tostring(cachedLocale),
        tostring(localeResource),
        tostring(localePath)
    ))
end

printLocaleDebug()

local function getAffectedRows(result)
    if type(result) == 'number' then return result end
    if result == true then return 1 end

    if type(result) == 'table' then
        return tonumber(result.affectedRows or result.changedRows or result.rowsChanged or result.affected or result[1]) or 0
    end

    return 0
end

local function dbWriteSucceeded(result)
    return getAffectedRows(result) > 0
end

--  verificações importantes ao iniciar o script.
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pr_lib.debug("info", lang("debug.onResourceStart"))

    pr_lib.db.query([[
        CREATE TABLE IF NOT EXISTS `pr_elevator_elevator` (
            `id`              int(11)          NOT NULL AUTO_INCREMENT,
            `name`            varchar(50)      DEFAULT NULL                 COMMENT 'Nome do elevador',
            `type`            varchar(50)      NOT NULL DEFAULT 'public'    COMMENT 'Tipo de acesso',
            `job`             varchar(50)      DEFAULT NULL                 COMMENT 'Nome do emprego/gang',
            `job_grade`       int(11)          DEFAULT 0                    COMMENT 'Nivel de cargo minimo',
            `password`        varchar(50)      DEFAULT NULL                 COMMENT 'Senha de acesso',
            `access_key`      varchar(50)      DEFAULT NULL                 COMMENT 'Chave de acesso do cartao',
            `citizenid`       varchar(50)      DEFAULT NULL                 COMMENT 'CitizenID do player',
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])
    pr_lib.debug("info", lang("debug.databaseCreated", { title = "pr_elevator_elevator" }))

    -- Migrar banco de dados de forma limpa sem gerar erros no oxmysql
    local columns = pr_lib.db.query("SHOW COLUMNS FROM `pr_elevator_elevator`")
    local existingColumns = {}
    if columns then
        for i = 1, #columns do
            local fieldName = columns[i].Field or columns[i].field
            if fieldName then
                existingColumns[fieldName] = true
            end
        end
    end

    if not existingColumns['type'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_elevator` ADD COLUMN `type` varchar(50) NOT NULL DEFAULT 'public'")
    end
    if not existingColumns['job_grade'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_elevator` ADD COLUMN `job_grade` int(11) DEFAULT 0")
    end
    if not existingColumns['password'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_elevator` ADD COLUMN `password` varchar(50) DEFAULT NULL")
    end
    if not existingColumns['citizenid'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_elevator` ADD COLUMN `citizenid` varchar(50) DEFAULT NULL")
    end

    pr_lib.db.query([[
        CREATE TABLE IF NOT EXISTS `pr_elevator_floor` (
            `id`              int(11)          NOT NULL AUTO_INCREMENT     COMMENT 'ID do andar - 1 id por andar!',
            `elevator_id`     int(11)          NOT NULL                    COMMENT 'ID do elevador',
            `name`            varchar(50)      NOT NULL DEFAULT 'Andar'    COMMENT 'Nome de exibicao do andar (ex: T, S1)',
            `floor`           int(11)          DEFAULT 0                   COMMENT 'Ordem/Numero do andar',
            `distance`        float            DEFAULT 2.0                 COMMENT 'Distância necessária para interagir com o elevador',
            `theme_color`     varchar(50)      DEFAULT NULL                COMMENT 'Cor do tema',
            `theme_background`varchar(50)      DEFAULT NULL                COMMENT 'Cor do fundo do tema',
            `coords`          json             DEFAULT NULL                COMMENT 'Coordenadas de spawn',
            `interact_coords` json             DEFAULT NULL                COMMENT 'Payload de interacao: vector3 legado ou prop DUI',
            `access_type`     varchar(50)      NOT NULL DEFAULT 'public'   COMMENT 'Tipo de acesso do andar',
            `access_job`      varchar(50)      DEFAULT NULL                COMMENT 'Emprego/gang do andar',
            `access_job_grade` int(11)         DEFAULT 0                   COMMENT 'Nivel minimo do emprego/gang',
            `access_password` varchar(50)      DEFAULT NULL                COMMENT 'Senha do andar',
            `access_key`      varchar(50)      DEFAULT NULL                COMMENT 'Metadata/chave do cartao',
            `access_item`     varchar(50)      DEFAULT NULL                COMMENT 'Item de cartao exigido',
            `access_citizenid` varchar(50)     DEFAULT NULL                COMMENT 'CitizenID permitido no andar',
            PRIMARY KEY (`id`),
            CONSTRAINT `fk_elevator_floor_elevator`
                FOREIGN KEY (`elevator_id`)
                REFERENCES `pr_elevator_elevator` (`id`)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])
    pr_lib.debug("info", lang("debug.databaseCreated", { title = "pr_elevator_floor" }))

    -- Migrar banco de dados de forma limpa para pr_elevator_floor se a tabela já existia sem as novas colunas
    local columnsFloor = pr_lib.db.query("SHOW COLUMNS FROM `pr_elevator_floor`")
    local existingColumnsFloor = {}
    if columnsFloor then
        for i = 1, #columnsFloor do
            local fieldName = columnsFloor[i].Field or columnsFloor[i].field
            if fieldName then
                existingColumnsFloor[fieldName] = true
            end
        end
    end

    if not existingColumnsFloor['name'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `name` varchar(50) NOT NULL DEFAULT 'Andar'")
    end
    if not existingColumnsFloor['interact_coords'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `interact_coords` json DEFAULT NULL")
    end
    if not existingColumnsFloor['access_type'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_type` varchar(50) NOT NULL DEFAULT 'public'")
    end
    if not existingColumnsFloor['access_job'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_job` varchar(50) DEFAULT NULL")
    end
    if not existingColumnsFloor['access_job_grade'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_job_grade` int(11) DEFAULT 0")
    end
    if not existingColumnsFloor['access_password'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_password` varchar(50) DEFAULT NULL")
    end
    if not existingColumnsFloor['access_key'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_key` varchar(50) DEFAULT NULL")
    end
    if not existingColumnsFloor['access_item'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_item` varchar(50) DEFAULT NULL")
    end
    if not existingColumnsFloor['access_citizenid'] then
        pr_lib.db.query("ALTER TABLE `pr_elevator_floor` ADD COLUMN `access_citizenid` varchar(50) DEFAULT NULL")
    end

    if not existingColumnsFloor['access_type'] then
        pr_lib.db.query([[
            UPDATE `pr_elevator_floor` f
            INNER JOIN `pr_elevator_elevator` e ON e.id = f.elevator_id
            SET
                f.access_type = COALESCE(NULLIF(e.type, ''), 'public'),
                f.access_job = e.job,
                f.access_job_grade = COALESCE(e.job_grade, 0),
                f.access_password = e.password,
                f.access_key = e.access_key,
                f.access_citizenid = e.citizenid
            WHERE COALESCE(NULLIF(e.type, ''), 'public') <> 'public'
        ]])
    end

    pr_lib.debug("info", lang("debug.onResourceStarted"))
    TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
end)

-- Registros de Callbacks do Servidor
pr_lib.callback.register('pr_elevator:server:getElevators', function(source)
    local result = pr_lib.db.query('SELECT * FROM pr_elevator_elevator')
    return result or {}
end)

pr_lib.callback.register('pr_elevator:server:getFloors', function(source, elevatorId)
    local result = pr_lib.db.query('SELECT * FROM pr_elevator_floor WHERE elevator_id = ?', {elevatorId})
    return result or {}
end)

pr_lib.callback.register('pr_elevator:server:getJobsList', function(source)
    local jobList = {}
    
    -- Tenta obter empregos do QBX
    local okJobs, jobs = pcall(function()
        return exports.qbx_core:GetJobs()
    end)
    -- Fallback para QBCore
    if not okJobs or not jobs then
        okJobs, jobs = pcall(function()
            return exports['qb-core']:GetCoreObject().Shared.Jobs
        end)
    end
    -- Fallback para ESX
    if not okJobs or not jobs then
        okJobs, jobs = pcall(function()
            return exports['es_extended']:getSharedObject().Jobs
        end)
    end

    if okJobs and jobs then
        for jobName, jobData in pairs(jobs) do
            table.insert(jobList, {
                name = jobName,
                label = lang('menu.job_prefix', jobData.label or jobName)
            })
        end
    end

    -- Tenta obter gangues do QBX/QBCore
    local okGangs, gangs = pcall(function()
        return exports.qbx_core:GetGangs()
    end)
    if not okGangs or not gangs then
        okGangs, gangs = pcall(function()
            return exports['qb-core']:GetCoreObject().Shared.Gangs
        end)
    end

    if okGangs and gangs then
        for gangName, gangData in pairs(gangs) do
            table.insert(jobList, {
                name = gangName,
                label = lang('menu.gang_prefix', gangData.label or gangName)
            })
        end
    end

    -- Lista fallback padrão
    if #jobList == 0 then
        jobList = {
            { name = 'police', label = lang('menu.job_prefix', lang('menu.police')) },
            { name = 'ambulance', label = lang('menu.job_prefix', lang('menu.ambulance')) },
            { name = 'mechanic', label = lang('menu.job_prefix', lang('menu.mechanic')) },
            { name = 'lostmc', label = lang('menu.gang_prefix', 'Lost MC') },
            { name = 'ballas', label = lang('menu.gang_prefix', 'Ballas') }
        }
    end

    table.sort(jobList, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return jobList
end)

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
        charid = 'citizenid',
        char_id = 'citizenid',
        identifier = 'citizenid',
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

local function readGrade(grade)
    if type(grade) == 'table' then
        return tonumber(grade.level or grade.grade or grade.rank or grade.id) or 0
    end

    return tonumber(grade) or 0
end

local function addIdentifier(access, value)
    value = cleanAccessValue(value)
    if not value then return end

    value = tostring(value):lower()
    access.identifiers[value] = true

    local withoutPrefix = value:match("^[^:]+:(.+)$")
    if withoutPrefix then
        access.identifiers[withoutPrefix] = true
    end
end

local function applyPlayerData(access, data)
    if type(data) ~= 'table' then return end

    if data.PlayerData then
        applyPlayerData(access, data.PlayerData)
    end

    addIdentifier(access, data.citizenid)
    addIdentifier(access, data.citizenId)
    addIdentifier(access, data.cid)
    addIdentifier(access, data.charid)
    addIdentifier(access, data.charId)
    addIdentifier(access, data.identifier)
    addIdentifier(access, data.license)

    if type(data.charinfo) == 'table' then
        addIdentifier(access, data.charinfo.citizenid)
        addIdentifier(access, data.charinfo.citizenId)
        addIdentifier(access, data.charinfo.cid)
        addIdentifier(access, data.charinfo.charid)
        addIdentifier(access, data.charinfo.charId)
    end

    if type(data.job) == 'table' then
        access.jobName = access.jobName or data.job.name
        access.jobGrade = math.max(access.jobGrade or 0, readGrade(data.job.grade))
    end

    if type(data.gang) == 'table' then
        access.gangName = access.gangName or data.gang.name
        access.gangGrade = math.max(access.gangGrade or 0, readGrade(data.gang.grade))
    end
end

local function getPlayerAccessData(src)
    local access = {
        jobName = nil,
        jobGrade = 0,
        gangName = nil,
        gangGrade = 0,
        identifiers = {}
    }

    addIdentifier(access, src)

    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        addIdentifier(access, identifier)
    end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player then applyPlayerData(access, player) end

        local okData, data = pcall(function()
            return exports.qbx_core:GetPlayerData(src)
        end)
        if okData and data then applyPlayerData(access, data) end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and core and core.Functions and core.Functions.GetPlayer then
            local player = core.Functions.GetPlayer(src)
            if player then applyPlayerData(access, player) end
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and esx and esx.GetPlayerFromId then
            local player = esx.GetPlayerFromId(src)
            if player then
                addIdentifier(access, player.identifier)
                if player.getIdentifier then
                    local okIdentifier, identifier = pcall(player.getIdentifier, player)
                    if okIdentifier then addIdentifier(access, identifier) end
                end
                if player.job then
                    access.jobName = access.jobName or player.job.name
                    access.jobGrade = math.max(access.jobGrade or 0, readGrade(player.job.grade))
                end
            end
        end
    end

    return access
end

local function hasConfiguredCreatorAccess(access, groups)
    if type(groups) ~= 'table' then return false end

    local hasRestriction = false
    for groupName, minimumGrade in pairs(groups) do
        hasRestriction = true
        local normalizedGroupName = tostring(groupName):lower()
        local requiredGrade = tonumber(minimumGrade) or 0

        local jobName = access.jobName and tostring(access.jobName):lower()
        local gangName = access.gangName and tostring(access.gangName):lower()

        if jobName == normalizedGroupName and (tonumber(access.jobGrade) or 0) >= requiredGrade then
            return true
        end

        if gangName == normalizedGroupName and (tonumber(access.gangGrade) or 0) >= requiredGrade then
            return true
        end
    end

    return not hasRestriction
end

pr_lib.callback.register('pr_elevator:server:canUseCreatorExport', function(source)
    local cfg = PR.ExportCreatorMenu or {}
    if cfg.enabled == false then return false end

    local access = getPlayerAccessData(source)
    local jobsAllowed = hasConfiguredCreatorAccess(access, cfg.jobs)
    local gangsAllowed = hasConfiguredCreatorAccess(access, cfg.gangs)

    if type(cfg.jobs) == 'table' and next(cfg.jobs) ~= nil and jobsAllowed then return true end
    if type(cfg.gangs) == 'table' and next(cfg.gangs) ~= nil and gangsAllowed then return true end

    return (type(cfg.jobs) ~= 'table' or next(cfg.jobs) == nil)
        and (type(cfg.gangs) ~= 'table' or next(cfg.gangs) == nil)
end)

local function getConfiguredKeycardItems(itemName)
    itemName = cleanAccessValue(itemName)
    if itemName then return { itemName } end

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
        for item, value in pairs(list) do
            if type(value) == 'table' then
                items[#items + 1] = value.item or value.name or item
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

local function metadataMatches(metadata, accessKey)
    if type(metadata) ~= 'table' then return false end

    local expected = tostring(accessKey)
    return tostring(metadata.acesso or '') == expected
        or tostring(metadata.access_key or '') == expected
        or tostring(metadata.accessKey or '') == expected
        or tostring(metadata.access or '') == expected
end

local function itemHasMetadata(item, accessKey)
    if type(item) ~= 'table' then return false end

    return metadataMatches(item.metadata or item.info, accessKey)
end

local function hasKeycard(src, accessKey, itemName)
    accessKey = cleanAccessValue(accessKey)
    if not accessKey then return false end

    local allowedItems = getConfiguredKeycardItems(itemName)
    local metadataVariants = {
        { acesso = accessKey },
        { access_key = accessKey },
        { accessKey = accessKey },
        { access = accessKey }
    }

    if GetResourceState('ox_inventory') == 'started' then
        for i = 1, #allowedItems do
            local item = allowedItems[i]
            for j = 1, #metadataVariants do
                local metadata = metadataVariants[j]

                local okCount, count = pcall(function()
                    return exports.ox_inventory:Search(src, 'count', item, metadata)
                end)
                if okCount and tonumber(count) and tonumber(count) > 0 then return true end

                local okItem, foundItem = pcall(function()
                    return exports.ox_inventory:GetItem(src, item, metadata, true)
                end)
                if okItem and tonumber(foundItem) and tonumber(foundItem) > 0 then return true end
                if okItem and type(foundItem) == 'table' and tonumber(foundItem.count) and tonumber(foundItem.count) > 0 then return true end

                local okSlots, slots = pcall(function()
                    return exports.ox_inventory:Search(src, 'slots', item, metadata)
                end)
                if okSlots and type(slots) == 'table' then
                    for _, slotItem in pairs(slots) do
                        if itemHasMetadata(slotItem, accessKey) then return true end
                    end
                end
            end

            local okSlots, slots = pcall(function()
                return exports.ox_inventory:Search(src, 'slots', item)
            end)
            if okSlots and type(slots) == 'table' then
                for _, slotItem in pairs(slots) do
                    if itemHasMetadata(slotItem, accessKey) then return true end
                end
            end
        end
    end

    return false
end

local function hasGroupAccess(accessData, access)
    local groupName = cleanAccessValue(accessData.job or accessData.access_job)
    if not groupName then return false end

    groupName = groupName:lower()
    local requiredGrade = tonumber(accessData.job_grade or accessData.access_job_grade) or 0
    local jobName = access.jobName and tostring(access.jobName):lower()
    local gangName = access.gangName and tostring(access.gangName):lower()

    return (jobName == groupName and (tonumber(access.jobGrade) or 0) >= requiredGrade)
        or (gangName == groupName and (tonumber(access.gangGrade) or 0) >= requiredGrade)
end

local function hasIdentifierAccess(accessData, access)
    local allowed = cleanAccessValue(accessData.citizenid or accessData.access_citizenid)
    if not allowed then return false end

    for value in allowed:gmatch("[^,;]+") do
        local identifier = cleanAccessValue(value)
        if identifier and access.identifiers[identifier:lower()] then
            return true
        end
    end

    return false
end

local function passwordMatches(expectedPassword, passwordAttempt)
    expectedPassword = cleanAccessValue(expectedPassword)
    passwordAttempt = cleanAccessValue(passwordAttempt)

    if not expectedPassword or not passwordAttempt then return false end
    return expectedPassword:upper() == passwordAttempt:upper()
end

local function buildAccessData(row)
    return {
        type = normalizeAccessType(row.access_type or row.elevator_type),
        job = cleanAccessValue(row.access_job or row.elevator_job),
        job_grade = row.access_job_grade or row.elevator_job_grade,
        password = cleanAccessValue(row.access_password or row.elevator_password),
        access_key = cleanAccessValue(row.access_key or row.elevator_access_key),
        access_item = cleanAccessValue(row.access_item),
        citizenid = cleanAccessValue(row.access_citizenid or row.elevator_citizenid)
    }
end

local function getAccessRequirements(accessData)
    local accessType = normalizeAccessType(accessData.type)
    local requirements = {
        group = accessData.job ~= nil,
        keycard = accessData.access_key ~= nil or accessData.access_item ~= nil,
        password = accessData.password ~= nil,
        identifier = accessData.citizenid ~= nil
    }

    if accessType == 'job' or accessType == 'gang' then
        requirements.group = true
    elseif accessType == 'citizenid' then
        requirements.identifier = true
    elseif accessType == 'keycard' then
        requirements.keycard = true
    elseif accessType == 'password' then
        requirements.password = true
    elseif accessType == 'job_keycard' then
        requirements.group = true
        requirements.keycard = true
    elseif accessType == 'job_password' then
        requirements.group = true
        requirements.password = true
    elseif accessType == 'job_citizenid' then
        requirements.group = true
        requirements.identifier = true
    end

    return requirements
end

local function denied(message)
    return {
        allowed = false,
        needsPassword = false,
        message = message
    }
end

local function allowed()
    return {
        allowed = true,
        needsPassword = false
    }
end

pr_lib.callback.register('pr_elevator:server:checkFloorAccess', function(source, floorId, passwordAttempt)
    floorId = tonumber(floorId)
    if not floorId then
        return denied(lang('menu.error_select_elevator'))
    end

    local result = pr_lib.db.query([[
        SELECT
            f.*,
            e.type AS elevator_type,
            e.job AS elevator_job,
            e.job_grade AS elevator_job_grade,
            e.password AS elevator_password,
            e.access_key AS elevator_access_key,
            e.citizenid AS elevator_citizenid
        FROM pr_elevator_floor f
        LEFT JOIN pr_elevator_elevator e ON e.id = f.elevator_id
        WHERE f.id = ?
        LIMIT 1
    ]], { floorId })

    local row = result and result[1]
    if not row then
        return denied(lang('menu.floor_not_found') or lang('menu.floor_missing'))
    end

    local accessData = buildAccessData(row)
    local requirements = getAccessRequirements(accessData)
    local playerAccess = getPlayerAccessData(source)

    if not requirements.group and not requirements.keycard and not requirements.password and not requirements.identifier then
        return allowed()
    end

    if requirements.group and not hasGroupAccess(accessData, playerAccess) then
        return denied(lang('menu.error_job_required'))
    end

    if requirements.identifier and not hasIdentifierAccess(accessData, playerAccess) then
        return denied(lang('menu.error_citizenid_required'))
    end

    if requirements.keycard and not accessData.access_key then
        return denied(lang('menu.error_keycard_required'))
    end

    if requirements.keycard and not hasKeycard(source, accessData.access_key, accessData.access_item) then
        return denied(lang('menu.error_keycard_required'))
    end

    if requirements.password then
        if not accessData.password then
            return denied(lang('menu.error_password_required'))
        end
        if not passwordAttempt then
            return {
                allowed = false,
                needsPassword = true,
                message = lang('menu.error_password_required')
            }
        end
        if passwordMatches(accessData.password, passwordAttempt) then return allowed() end
        return denied(lang('menu.invalid_password'))
    end

    return allowed()
end)

-- Eventos de Modificação do Banco de Dados
RegisterNetEvent('pr_elevator:server:createElevator', function(name, elevatorType, job, jobGrade, password, accessKey, citizenid)
    local src = source

    pr_lib.db.insert('INSERT INTO pr_elevator_elevator (name, type, job, job_grade, password, access_key, citizenid) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, elevatorType, job, jobGrade, password, accessKey, citizenid
    }, function(insertId)
        if insertId then
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.elevator_created'), 'success')
            TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
        else
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.create_failed'), 'error')
        end
    end)
end)

RegisterNetEvent('pr_elevator:server:deleteElevator', function(elevatorId)
    local src = source
    pr_lib.db.execute('DELETE FROM pr_elevator_elevator WHERE id = ?', {elevatorId}, function(rowsChanged)
        TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.elevator_deleted'), 'success')
        TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
    end)
end)

RegisterNetEvent('pr_elevator:server:updateElevator', function(elevatorId, name)
    local src = source
    pr_lib.db.execute('UPDATE pr_elevator_elevator SET name = ? WHERE id = ?', {name, elevatorId}, function(rowsChanged)
        if not dbWriteSucceeded(rowsChanged) then
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.update_failed'), 'error')
        else
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.elevator_updated'), 'success')
            TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
        end
    end)
end)

RegisterNetEvent('pr_elevator:server:createFloor', function(elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnCoords, interactCoords, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid)
    local src = source
    local spawnJson = json.encode(spawnCoords)
    local interactJson = json.encode(interactCoords)
    accessType = accessType or 'public'
    accessJobGrade = tonumber(accessJobGrade) or 0

    pr_lib.db.insert('INSERT INTO pr_elevator_floor (elevator_id, name, floor, distance, theme_color, theme_background, coords, interact_coords, access_type, access_job, access_job_grade, access_password, access_key, access_item, access_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid
    }, function(insertId)
        if insertId then
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_created'), 'success')
            TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
        else
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_create_failed'), 'error')
        end
    end)
end)

RegisterNetEvent('pr_elevator:server:deleteFloor', function(floorId)
    local src = source
    pr_lib.db.execute('DELETE FROM pr_elevator_floor WHERE id = ?', {floorId}, function(rowsChanged)
        TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_deleted'), 'success')
        TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
    end)
end)

RegisterNetEvent('pr_elevator:server:updateFloor', function(floorId, elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnCoords, interactCoords, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid, targetSwapFloorId, oldFloorOrder)
    local src = source
    local spawnJson = json.encode(spawnCoords)
    local interactJson = json.encode(interactCoords)
    accessType = accessType or 'public'
    accessJobGrade = tonumber(accessJobGrade) or 0

    if targetSwapFloorId then
        -- Estamos trocando pedidos de chão!
        -- Primeiro atualize a ordem do piso de troca de destino para oldFloorOrder
        pr_lib.db.execute('UPDATE pr_elevator_floor SET floor = ? WHERE id = ?', {oldFloorOrder, targetSwapFloorId}, function(rowsChanged1)
            -- Em seguida, atualize o piso editado
            pr_lib.db.execute('UPDATE pr_elevator_floor SET name = ?, floor = ?, distance = ?, theme_color = ?, theme_background = ?, coords = ?, interact_coords = ?, access_type = ?, access_job = ?, access_job_grade = ?, access_password = ?, access_key = ?, access_item = ?, access_citizenid = ? WHERE id = ?', {
                floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid, floorId
            }, function(rowsChanged2)
                if not dbWriteSucceeded(rowsChanged2) then
                    TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_update_failed'), 'error')
                else
                    TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
                end
            end)
        end)
    else
        -- Apenas atualizando o piso editado
        pr_lib.db.execute('UPDATE pr_elevator_floor SET name = ?, floor = ?, distance = ?, theme_color = ?, theme_background = ?, coords = ?, interact_coords = ?, access_type = ?, access_job = ?, access_job_grade = ?, access_password = ?, access_key = ?, access_item = ?, access_citizenid = ? WHERE id = ?', {
            floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson, accessType, accessJob, accessJobGrade, accessPassword, accessKey, accessItem, accessCitizenid, floorId
        }, function(rowsChanged)
            if not dbWriteSucceeded(rowsChanged) then
                TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_update_failed'), 'error')
            else
                TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
            end
        end)
    end
end)

RegisterNetEvent('pr_elevator:server:giveKeycard', function(itemName, accessKey)
    local src = source
    local item = itemName or PR.keycardItem or 'elevator_card'
    local count = 1
    local metadata = {
        acesso = accessKey,
        access_key = accessKey,
        accessKey = accessKey,
        access = accessKey,
        description = (lang('menu.keycard_access')):format(accessKey)
    }

    local success = pr_lib.inventory.AddItem(src, item, count, metadata)
    -- Notify regardless of return type because some inventory bridges might not return bool
    TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.keycard_given'), 'success')
end)
