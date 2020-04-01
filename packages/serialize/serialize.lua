local crypt = require "crypt"
local watch = require "watch"
local patch = require "patch"
local save_entity = require "v2.save".entity
local stringify_entity = require "v2.stringify".entity

local function create()
    return crypt.uuid()
end

local function entity(w, eid)
    return stringify_entity(w._policies[eid], save_entity(w, eid))
end

return {
    create = create,
    watch = watch,
    patch = patch,
    entity = entity,
}
