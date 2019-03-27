-- luacheck: globals log
local log = log and log(...) or print
require "iuplua"
local iupcontrols   = import_package "ant.iupcontrols"
local tree = iupcontrols.tree
local util = require "util"

local fs_dir_tree = setmetatable({},{__index = tree})



function fs_dir_tree:show_dir(abs_path)
    
end





function fs_dir_tree.new(config)
    local default_config = {
        HIDEBUTTONS ="YES",
        HIDELINES   ="YES", 
        IMAGELEAF   ="IMGLEAF",
        IMAGEBRANCHCOLLAPSED = "IMGLEAF",
        IMAGEBRANCHEXPANDED = "IMGLEAF"
    }
    local merge_config
    if config ~= nil then
        merge_config = util.merge_config(config,default_config)
    else
        merge_config = default_config
    end
    local tree = tree.new(merge_config)
    return setmetatable(tree,{ __index = fs_dir_tree })
end

return fs_dir_tree