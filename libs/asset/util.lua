local path = require "filesystem.path"

local util = {}
util.__index = util



function util.parse_elem(value, memfile_creator, insert_op)        
    local t = type(value)
    if t == "string" then
        insert_op(value)
    elseif t == "table" then
        local seri = require "filesystem.serialize"
        local fn = memfile_creator()
        seri.save(fn, value)
        insert_op(fn)
    end
end

function util.parse_elems(value, cb)
    for k, v in pairs(value) do
        local func = cb[k]
        if func == nil then
            error "not support this type"
        end
        func(k, v)
    end
end

local db = require "debugger"

function util.check_join_parent_path(fn, parent)
    if not path.has_parent(fn) then
        local pp = path.parent(parent)
        local nomem_pp = pp:match("mem://(.+)")    
        local ff = nomem_pp and nomem_pp or pp        
        return path.join(ff, fn)
    end

    return fn
end

return util