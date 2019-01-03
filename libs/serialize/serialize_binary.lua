local ecs = ...

ecs.import "serialize.serialize_system"

local fs = require "filesystem"
local assetmgr = require "asset"

local save_to_binary = ecs.system "serialize_to_binary"
save_to_binary.singleton "serialization_tree"

save_to_binary.depend "serialize_save_system"

local function get_map_filename(mapname)	
    local subfolder = assetmgr.assetdir() / "map"
    fs.create_directories(subfolder)

    return subfolder / mapname .. ".bin"
end

function save_to_binary:update()    

    local s_tree = self.serialization_tree
    local enable = s_tree.binary
    if enable then
        local filepath = get_map_filename("test_world")

    end
end