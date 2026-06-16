-- aqui servidor do sistema de menu para gerenciamento dos elevadores e andares
local lang = pr_lib.locale()

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
                label = ("[Job] " .. (jobData.label or jobName))
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
                label = ("[Gang] " .. (gangData.label or gangName))
            })
        end
    end

    -- Lista fallback padrão
    if #jobList == 0 then
        jobList = {
            { name = 'police', label = '[Job] Police' },
            { name = 'ambulance', label = '[Job] Ambulance' },
            { name = 'mechanic', label = '[Job] Mechanic' },
            { name = 'lostmc', label = '[Gang] Lost MC' },
            { name = 'ballas', label = '[Gang] Ballas' }
        }
    end

    table.sort(jobList, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return jobList
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
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), 'Erro ao criar elevador.', 'error')
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

RegisterNetEvent('pr_elevator:server:createFloor', function(elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnCoords, interactCoords)
    local src = source
    local spawnJson = json.encode(spawnCoords)
    local interactJson = json.encode(interactCoords)

    pr_lib.db.insert('INSERT INTO pr_elevator_floor (elevator_id, name, floor, distance, theme_color, theme_background, coords, interact_coords) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson
    }, function(insertId)
        if insertId then
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.floor_created'), 'success')
            TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
        else
            TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), 'Erro ao criar andar.', 'error')
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

RegisterNetEvent('pr_elevator:server:updateFloor', function(floorId, elevatorId, floorName, floorOrder, distance, themeColor, themeBackground, spawnCoords, interactCoords, targetSwapFloorId, oldFloorOrder)
    local src = source
    local spawnJson = json.encode(spawnCoords)
    local interactJson = json.encode(interactCoords)

    if targetSwapFloorId then
        -- Estamos trocando pedidos de chão!
        -- Primeiro atualize a ordem do piso de troca de destino para oldFloorOrder
        pr_lib.db.execute('UPDATE pr_elevator_floor SET floor = ? WHERE id = ?', {oldFloorOrder, targetSwapFloorId}, function(rowsChanged1)
            -- Em seguida, atualize o piso editado
            pr_lib.db.execute('UPDATE pr_elevator_floor SET name = ?, floor = ?, distance = ?, theme_color = ?, theme_background = ?, coords = ?, interact_coords = ? WHERE id = ?', {
                floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson, floorId
            }, function(rowsChanged2)
                if not (rowsChanged2 and rowsChanged2 > 0) then
                    TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), 'Erro ao atualizar andar.', 'error')
                else
                    TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
                end
            end)
        end)
    else
        -- Apenas atualizando o piso editado
        pr_lib.db.execute('UPDATE pr_elevator_floor SET name = ?, floor = ?, distance = ?, theme_color = ?, theme_background = ?, coords = ?, interact_coords = ? WHERE id = ?', {
            floorName, floorOrder, distance, themeColor, themeBackground, spawnJson, interactJson, floorId
        }, function(rowsChanged)
            if not (rowsChanged and rowsChanged > 0) then
                TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), 'Erro ao atualizar andar.', 'error')
            else
                TriggerClientEvent('pr_elevator:client:refreshElevators', -1)
            end
        end)
    end
end)

RegisterNetEvent('pr_elevator:server:giveKeycard', function(accessKey)
    local src = source
    local item = PR.keycardItem or 'elevator_card'
    local count = 1
    local metadata = {
        access_key = accessKey,
        description = ('Acessos: %s'):format(accessKey)
    }

    local success = pr_lib.inventory.AddItem(src, item, count, metadata)
    -- Notify regardless of return type because some inventory bridges might not return bool
    TriggerClientEvent('pr_elevator:client:notify', src, lang('menu.title'), lang('menu.keycard_given'), 'success')
end)
