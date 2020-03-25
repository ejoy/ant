local crypt = require "crypt"
local watch = require "watch"
local save_entity = require "v2.save".entity
local stringify_entity = require "v2.stringify".entity

local function create()
    return crypt.uuid()
end

local function entity(w, eid)
    return stringify_entity(w, w._policies[eid], save_entity(w, eid))
end

return {
    create = create,
    watch = watch,
    entity = entity,
}
