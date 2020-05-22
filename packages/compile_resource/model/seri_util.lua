local seri_util = {}; seri_util.__index = seri_util

local datalist = require "datalist"
local sort_pairs = require "sort_pairs"

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local PATTERN <const> = "%a%d/%-_."
local PATTERN <const> = "^["..PATTERN.."]["..PATTERN.."]*$"

function seri_util.stringify_basetype(v)
    local t = type(v)
    if t == 'number' then
        if math.type(v) == "integer" then
            return ('%d'):format(v)
        else
            return convertreal(v)
        end
    elseif t == 'string' then
        if v:match(PATTERN) then
            return v
        else
            return datalist.quote(v)
        end
    elseif t == 'boolean'then
        if v then
            return 'true'
        else
            return 'false'
        end
    elseif t == 'function' then
        return 'null'
    end
    error('invalid type:'..t)
end

function seri_util.seri_vector(v, lastv)
    lastv = lastv or 0
    if #v == 1 then
        return ("{%d, %d, %d, %d"):format(v[1], v[1], v[1], lastv)
    end

    if #v == 3 then
        return ("{%d, %d, %d, %d"):format(v[1], v[2], v[3], lastv)
    end

    if #v == 4 then
        return ("{%d, %d, %d, %d"):format(v[1], v[2], v[3], v[4])
    end

    error("invalid vector")
end

local depth_cache = {}
local function get_depth(d)
    if d == 0 then
        return ""
    end
    local dc = depth_cache[d]
    if dc then
        return dc
    end

    local t = {}
    local tab<const> = "  "
    for i=1, d do
        t[#t+1] = tab
    end
    local dd = table.concat(t)
    depth_cache[d] = dd
    return dd
end

local function resource_type(prefix, v)
    assert(type(v) == "string")
    return prefix .. "$resource " .. seri_util.stringify_basetype(v)
end

local typeclass = {
    mesh = function (depth, v)
        return get_depth(depth) .. resource_type("mesh: ", v)
    end,
    material = function (depth, v)
        return get_depth(depth) .. resource_type("material: ", v)
    end,
    transform = function (depth, v)
        assert(type(v) == "table")
        local tt = {get_depth(depth) .. "transform: $transform"}
        if v.srt then
            local seri_srt = get_depth(depth+1) .. "srt: $srt"
            local s, r, t = v.srt.s, v.srt.r, v.srt.t
            if s == nil or r == nil or t == nil then
                tt[#tt+1] = seri_srt .. " {}"
            else
                tt[#tt+1] = seri_srt
                if s then
                    tt[#tt+1] = get_depth(depth+2) .. "s:" .. seri_util.seri_vector(s)
                end
                if r then
                    tt[#tt+1] = get_depth(depth+2) .. "r:" .. seri_util.seri_vector(r)
                end
                if t then
                    tt[#tt+1] = get_depth(depth+2) .. "t:" .. seri_util.seri_vector(t)
                end
            end
            
        end

        return table.concat(tt, "\n")
    end
}

seri_util.get_depth = get_depth
seri_util.typeclass = typeclass

function seri_util.seri_table(data, depth, out)
    for compname, comp in sort_pairs(data) do
        local tc = seri_util.typeclass[compname]
        if tc == nil then
            assert(type(comp) ~= "table" and type(comp) ~= "userdata")
            out[#out+1] = seri_util.get_depth(depth+1) .. compname .. ":" .. seri_util.stringify_basetype(comp)
        else
            out[#out+1] = tc(depth+1, comp)
        end
    end
end

function seri_util.seri_perfab(world, entities)
    local out = {"---"}
    out[#out+1] = "{mount 1 root}"
    local map = {}
    for idx, eid in ipairs(entities) do
        map[eid] = idx
    end
    for idx=2, #entities do
        local e = world[entities[idx]]
        local connection = e.connection
        if connection then
            for _, c in ipairs(connection) do
                local target_eid = c[2]
                assert(world[target_eid])
                out[#out+1] = ("{mount %d %d}"):format(idx, map[target_eid])
            end
        end
    end

    local depth = 0
    for _, eid in ipairs(entities) do
        local e = world[eid]

        out[#out+1] = "---"
        out[#out+1] = "policy:"
        for _, pn in ipairs(e.policy) do
            out[#out+1] = seri_util.get_depth(depth+1) .. pn
        end

        out[#out+1] = "data:"
        seri_util.seri_table(e.data, depth, out)
    end

    return table.concat(out, "\n")
end

function seri_util.seri_pbrm(pbrm)
    local out = {}
    local depth = 0
    local function seri_texture(tex, depth, r)
        if tex then
            r[#r+1] = seri_util.get_depth(depth) .. "texutre: $resource " .. tex
        end
    end

    local function seri_basetype(name, v)
        return name .. ": " .. seri_util.stringify_basetype(v)
    end

    local function seri_child(name, v, depth, r, op)
        local f = v[name]
        if f then
            r[#r+1] = seri_util.get_depth(depth) .. name .. ":" .. op(f)
        end
    end

    local function seri_pbrm_elem(compname, op)
        local s = {}
        op(s)
        if next(s) then
            return compname .. ":\n" .. table.concat(s, "\n")
        end
    end

    local function seri_comp_texture_factor(compname, comp, depth)
        return seri_pbrm_elem(compname, function (s)
            seri_texture(comp.texture, depth, s)
            seri_child("factor", comp, depth, s, seri_util.seri_vector)
        end)
    end

    local function seri_comp_texture(compname, comp, depth)
        return seri_pbrm_elem(compname, function (s)
            seri_texture(comp.texture, depth, s)
        end)
    end

    local typeclass = {
        basecolor = seri_comp_texture_factor,
        metallic_roughness = function(compname, comp, depth)
            return seri_pbrm_elem(compname, function(s)
                seri_texture(comp.texture, depth, s)
                
                seri_child("roughness_factor", comp, depth, s, seri_util.stringify_basetype)
                seri_child("metallic_factor", comp, depth, s, seri_util.stringify_basetype)
            end)
        end,
        normal      = seri_comp_texture,
        occlusion   = seri_comp_texture,
        emissive    = seri_comp_texture_factor,
    }

    for name, comp in sort_pairs(pbrm) do
        local tc = typeclass[name]
        if tc == nil then
            out[#out+1] = seri_basetype(name, comp)
        else
            out[#out+1] = tc(name, comp, depth+1)
        end
    end

    return table.concat(out, "\n")
end

return seri_util