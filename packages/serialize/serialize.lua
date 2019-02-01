
local save = require "save"
local load = require "load"
local stringify = require "stringify"

local function save_world(w)
    return stringify(w, save(w))
end

local function load_world(w, t)
    return load(w, t)
end

return {
    save_world = save_world,
    load_world = load_world,
}
