local ecs = ...
local world = ecs.world
local seri_util = require "serialize.util"
local path = require "filesystem.path"
local assetmgr = require "asset"

local to_luatabletext = ecs.system "serialize_to_luatabletext"
to_luatabletext.singleton "serialization_tree"

local function get_map_filename(mapname)
    local subfolder = "map"
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
        local assetmappath = path.join(assetmgr.assetdir(), filename)
        seri_util.save(assetmappath, wrapper)
        s_tree.luatext = false
        dprint("finish save, file : ", filename)
    end    
end

-- load
local from_luatabletext = ecs.system "serialize_from_luatabletext"
from_luatabletext.singleton "serialization_tree"

function from_luatabletext.notify:load_from_luatext()
    local s_tree = self.serialization_tree
    local enable = s_tree.luatext
    if enable then        
        local mapsubpath = get_map_filename("test_world")
        local filename = assetmgr.find_valid_asset_path(mapsubpath)
        if filename then
            local wrapper = seri_util.load(filename)
            s_tree.root = wrapper.root
            s_tree.luatext = false

            world:change_component(-1, "load_from_seri_tree")
            world:notify()
        else
            print("not found world file : ", mapsubpath)
        end
    end
end
