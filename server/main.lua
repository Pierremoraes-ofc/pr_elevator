RegisterNetEvent('pr_elevator:selectFloor', function(floor)
    local src = source
    if type(floor) ~= 'table' then return end

    local coords = floor.coords or floor.Coords or floor
    if type(coords) ~= 'table' then return end

    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    local heading = tonumber(coords.heading or coords.w or coords[4]) or 0.0

    if not x or not y or not z then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    SetEntityCoords(ped, x, y, z)
    SetEntityHeading(ped, heading)
end)
