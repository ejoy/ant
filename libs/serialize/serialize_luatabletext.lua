local ecs = ...

local seri_util = require "serialize.util"
local path = require "filesystem.path"

local to_luatabletext = ecs.system "serialize_to_luatabletext"

to_luatabletext.singleton "serialization_tree"
to_luatabletext.singleton "serialize_test_component"

to_luatabletext.depend "serialize_save_system"

local function get_map_filename(mapname)
    local subfolder = "assets/map"
    path.create_dirs(subfolder)

    return path.join(subfolder, mapname .. ".lua")
end

function to_luatabletext:update()
    local test_state = self.serialize_test_component.state
    if test_state == "save" then
        local s_tree = self.serialization_tree
        local enable = s_tree.luatext
        if enable then
            local filename = get_map_filename(s_tree.name)

            local wrapper = {}
            wrapper.root = s_tree.root
            seri_util.save(filename, wrapper)
            s_tree.luatext = false
        end

        self.serialize_test_component.state = ""
    end
end

-- load
local from_luatabletext = ecs.system "serialize_from_luatabletext"
from_luatabletext.singleton "serialization_tree"
from_luatabletext.singleton "serialize_test_component"

from_luatabletext.dependby "serialize_load_system"

function from_luatabletext:update()    
    local test_state = self.serialize_test_component.state
    if test_state == "load" then
        local s_tree = self.serialization_tree
        local enable = s_tree.luatext
        if enable then
            local filename = get_map_filename(s_tree.name)
            local wrapper = seri_util.load(filename)
            s_tree.root = wrapper.root
            s_tree.luatext = false
        end
    end

end
