ElevatorSettings = {}
function ElevatorSettings.normalize(value)
    if type(value)~='table' then return nil,'invalid_settings' end
    if value.mode~='target' and value.mode~='interact' and value.mode~='both' then return nil,'invalid_mode' end
    if type(value.respectWalls)~='boolean' then return nil,'invalid_walls' end
    local offset,distance=tonumber(value.frontOffset),tonumber(value.distance)
    if not offset or offset~=offset or offset<0.05 or offset>1 then return nil,'invalid_offset' end
    if not distance or distance~=distance or distance<0.5 or distance>5 then return nil,'invalid_distance' end
    return {mode=value.mode,respectWalls=value.respectWalls,frontOffset=offset,distance=distance}
end
