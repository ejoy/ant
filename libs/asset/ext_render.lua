local require = import and import(...) or require
local rawtable = require "rawtable"
local path = require "filesystem.path"
local util = require "util"

return function(filename, assetlib)
    local render = rawtable(filename)
    
    local cb = {
        materials = function (key, vv)
            assert(type(vv) == "table")
            
            local materials = {}
            for idx, v in pairs(vv) do
                util.parse_elem(v, 
                                function ()
                                    return string.format("mem://%s-%d.material", path.remove_ext(filename), idx)                    
                                end, 
                                function (fn)                    
                                    local pp = util.check_join_parent_path(fn, filename)                                    
                                    table.insert(materials, assetlib[pp])
                                end)
            end

            render.materials = materials
        end,
        mesh = function (_, v)
            util.parse_elem(v,
                        function() return string.format("mem://%s.mesh", path.remove_ext(filename)) end, 
                        function (fn) 
                            local pp = util.check_join_parent_path(fn, filename)                            
                            render.mesh = assetlib[pp] 
                        end)
        end
    }

    util.parse_elems(render, cb)
    return render
end