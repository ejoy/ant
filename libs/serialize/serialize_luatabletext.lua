local ecs = ...
local world = ecs.world
local seri_util = require "serialize.util"
local path = require "filesystem.path"

local to_luatabletext = ecs.system "serialize_to_luatabletext"
to_luatabletext.singleton "serialization_tree"

local function get_map_filename(mapname)
    local subfolder = "assets/map"
    path.create_dirs(subfolder)

    return path.join(subfolder, mapname .. ".lua")
end

function to_luatabletext.notify:save_tofile()
    local s_tree = self.serialization_tree
    local enable = s_tree.luatext
    if enable then
        local filename = get_map_filename(s_tree.name)

        local wrapper = {}
        wrapper.root = s_tree.root
        seri_util.save(filename, wrapper)
        s_tree.luatext = false
    end
    dprint("finish save, file : ", filename)
end

-- load
local from_luatabletext = ecs.system "serialize_from_luatabletext"
from_luatabletext.singleton "serialization_tree"

function from_luatabletext.notify:load_from_luatext()
    local s_tree = self.serialization_tree
    local enable = s_tree.luatext
    if enable then
        local filename = get_map_filename("test_world")
        local wrapper = seri_util.load(filename)
        s_tree.root = wrapper.root
        s_tree.luatext = false

        world:change_component(-1, "load_from_seri_tree")
        world:notify()
    end
end
