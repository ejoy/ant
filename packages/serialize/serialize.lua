local stringify = require "stringify"

local function prefab(w, entities, args)
    local t = {{}}
    local actions = t[1]
    local slot = {}
    for i, eid in ipairs(entities) do
        slot[eid] = i
    end
    for i, eid in ipairs(entities) do
        local template = w._prefabs[eid].policy
        local e = {policy={},data={}}
        t[#t+1] = e
        local dataset = w[eid]
        for _, name in ipairs(template.connection) do
            local object = w._class.connection[name]
            assert(object and object.save)
            local res = object.save(w[eid])
            if args[i] and args[i][name] then
                actions[#actions+1] = {name, i, args[i][name]}
            elseif slot[res] then
                actions[#actions+1] = {name, i, slot[res]}
            else
                error(("entity %d connection `%s` cannot be serialized."):format(eid, name))
            end
        end
        for _, p in ipairs(template.policy) do
            e.policy[#e.policy+1] = p
        end
        for _, name in ipairs(template.component) do
            e.data[name] = dataset[name]
        end
        table.sort(e.policy)
    end
    return stringify(t, w._typeclass)
end

return {
    watch = require "watch",
    patch = require "patch",
    prefab = prefab,
    dl = require "dl",
    stringify = require "stringify",
}
