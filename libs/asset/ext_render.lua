local require = import and import(...) or require
local rawtable = require "rawtable"
local path = require "filesystem.path"
local util = require "util"

local render_mt = {}
render_mt.__index = render_mt
function render_mt:get_elem(eidx)
    local mnum = #self
    assert(eidx <= mnum)
    return self[eidx]
end
function render_mt:get_material(midx, bidx)
    local e = self:get_elem(midx)
    local bindings = e.binding
    local bnum = #bindings
    assert(bnum >= bidx)
    return bindings[bidx].material
end
function render_mt:get_uniform(midx, bidx, uname)
    local material = self:get_material(midx, bidx)
    local uniform = material.uniform
    if uniform then
        local defines = uniform.defines
        return defines and defines[uname] or nil
    end

    return nil
end

return function(filename, assetmgr)
    local assetmgr = require "asset"

    local render = assert(rawtable(filename))
    
    local function load_render_elem(elem)
        -- load mesh
        local mesh = assetmgr.load(elem.mesh)

        -- load materail binding
        local binding = {}
        do
            local b = elem.binding

            local function load_binding_elem(b_elem)
                local material = assetmgr.load(b_elem.material)
                local meshids = b_elem.meshids
                if meshids then
                    for _, id in ipairs(meshids) do
                        local mgroups = mesh.handle.group
                        if mgroups[id] == nil then
                            error(string.format("id = %d not exist in mesh groups. in render file : %s", id, filename))
                        end
                    end
                else
                    local num = #mesh.handle.group
                    meshids = {}
                    for i=1, num do
                        table.insert(meshids, i)
                    end
                end

                return {material=material, meshids=meshids}
            end

            local num = #b
            if num ~= 0 then
                for _, v in ipairs(b) do
                    local e_binding = load_binding_elem(v)
                    table.insert(binding, e_binding)
                end
            else
                table.insert(binding, load_binding_elem(b))
            end

        end

        -- read srt
        local srt = elem.srt
        do        
            if srt then
                local function read_srt_elem_with_option(v, opt, name)
                    if v == nil then
                        return {opt, opt, opt}
                    end
                    local num = #v  
                    if num == 1 then
                        local t = v[1]
                        v[2], v[3] = t, t
                    elseif num <= 3 then
                        for i=1, 3 do
                            if v[i] == nil then 
                                v[i] = opt 
                            end
                        end
                    else
                        error(string.format("srt.%s format must srt={%s={}/{1}/{1,2}/{1,2,3}}", name, name))
                        return nil
                    end

                    return v
                end
                
                srt.s = read_srt_elem_with_option(srt.s, 1, "s")                
                srt.r = read_srt_elem_with_option(srt.r, 0, "r")
                srt.t = read_srt_elem_with_option(srt.t, 0, "t")
            else
                srt = {s={1, 1, 1}, r={0, 0, 0}, t={0, 0, 0}}
            end
        end


        return {mesh=mesh, binding=binding, srt=srt}
    end

    local root = render.root
    local result = {}
    if root then
        for _, v in ipairs(root) do
            local e = load_render_elem(v)
            table.insert(result, e)
        end
    else
        table.insert(result, load_render_elem(render))
    end

    return setmetatable(result, render_mt)
end