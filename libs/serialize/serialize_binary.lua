local ecs = ...
local world = ecs.world

ecs.import "serialize.serialize_system"

local fu = require "filesystem.util"

local save_to_binary = ecs.system "serialize_to_binary"
save_to_binary.singleton "serialization_tree"

save_to_binary.depend "serialize_save_system"

local function get_map_filename(mapname)
    local subfolder = "assets/map"
    fu.create_dirs(subfolder)

    return path.join(subfolder, mapname .. ".bin")
end

function save_to_binary:update()    

    local s_tree = self.serialization_tree
    local enable = s_tree.binary
    if enable then
        local filename = get_map_filename("test_world")

    end
end