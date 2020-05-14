local save = require "save"

local function prefab(w, entities, args)
    local out = {}
    local slot = {}
    out[#out+1] = '---'
    for i, eid in ipairs(entities) do
        slot[eid] = i
    end
    for i, eid in ipairs(entities) do
        local info = w._prefabs[eid]
        local connections = info[1].initargs[info[2]].connection
        for _, name in ipairs(connections) do
            local object = w._class.connection[name]
            assert(object and object.methodfunc and object.methodfunc.save)
            local res = object.methodfunc.save(w[eid])
            if args[i] and args[i][name] then
                out[#out+1] = ("{%s %d %s}"):format(name, i, args[i][name])
            elseif slot[res] then
                out[#out+1] = ("{%s %d %d}"):format(name, i, slot[res])
            else
                error(("entity %d connection `%s` cannot be serialized."):format(eid, name))
            end
        end
    end
    return save.prefab(w, entities, out)
end

return {
    watch = require "watch",
    patch = require "patch",
    entity = save.entity,
    prefab = prefab,
    dl = require "dl",
    stringify = require "stringify",
}
