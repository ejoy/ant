local crypt = require "crypt"
local watch = require "watch"
local save_entity = require "v2.save".entity
local stringify_entity = require "v2.stringify".entity

local function create()
    return crypt.uuid()
end

local function serialize_entity(w, eid, policies)
    return stringify_entity(w, policies, save_entity(w, eid))
end

return {
    create = create,
    serialize_entity = serialize_entity,
    watch = watch,
}
