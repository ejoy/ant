
local save = require "save"
local load = require "load"
local stringify = require "stringify"
local datalist = require 'datalist'

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

local thread = require "thread"

local watch = require "watch"
local function entity2tbl(w,eid)
    local tbl = watch.query(w,nil,tostring(eid))
    return tbl
end

return {
    save_world = save_world,
    save_entity = save_entity,
    load_world = load_world,
    load_entity = load_entity,
    v2 = require "v2.serialize",
    create = create,
    watch = require "watch",
    --binary pack&unpack table
    pack = thread.pack,
	unpack = thread.unpack,
    --convert betweend table and entity/component
    entity2tbl = entity2tbl,
    world2tbl = save.world,
}
