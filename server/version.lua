-- server/version.lua
local REPO_OWNER = "Pierremoraes-ofc"
local REPO_NAME  = "pr_elevator"

-- Só roda no server para não abrir requisição no client
if IsDuplicityVersion() then
    CreateThread(function()
        -- Aguarda o server subir completamente
        Wait(5000)

        if pr_lib and PR.versionCheck then
            pr_lib.versionCheck(("%s/%s"):format(REPO_OWNER, REPO_NAME))
        end
    end)
end
