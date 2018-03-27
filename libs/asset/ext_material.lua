local require = import and import(...) or require

local rawtable = require "rawtable"
local util = require "util"
local path = require "filesystem.path"

return function(filename, assetlib)    
    print(filename)
    local material = assert(rawtable(filename))
    local function parse_elem(k, v)        
        util.parse_elem(v,
            function ()return string.format("mem://%s.%s", path.remove_ext(filename), k) end,
            function (fn) 
                local pp = util.check_join_parent_path(fn, filename)                
                material[k] = assetlib[pp]
            end)
    end

    util.parse_elems(material, 
                    setmetatable({},{
                        __index = function () return parse_elem end
                    }))

    return material
end