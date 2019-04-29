
local save = require "save"
local load = require "load"
local stringify = require "stringify"

local function save_world(w)
    return stringify.world(w, save.world(w))
end

local function save_entity(w, eid)
    return stringify.entity(w, save.entity(w, eid))
end

local function load_world(w, t)
    return load.world(w, t)
end

local function load_entity(w, t)
    return load.entity(w, t)
end

local crypt = require "crypt"

local function create()
    return crypt.uuid()
end

return {
    save_world = save_world,
    save_entity = save_entity,
    load_world = load_world,
    load_entity = load_entity,
    create = create,
    watch = require "watch",
}
