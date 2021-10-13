local ecs = ...

local m = ecs.action "name"
function m.init(prefab, i, value)
    prefab[value] = prefab[i]
end

local m = ecs.action "import"
function m.init(prefab, i, value)
    local name = value[1]
    local key = value[2]
    prefab[name] = assert(prefab[i])[key]
end
