local REPO_OWNER = "Pierremoraes-ofc"
local REPO_NAME = "pr_elevator"

if IsDuplicityVersion() then
    CreateThread(function()
        Wait(5000)
        if PR.versionCheck then
            if pr_lib and pr_lib.versionCheck then
                pr_lib.versionCheck(("%s/%s"):format(REPO_OWNER, REPO_NAME))
            end
        end
    end)
end
