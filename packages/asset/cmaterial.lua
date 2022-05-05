local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr = require "asset"
local ext_material = require "ext_material"

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local rmat      = require "render.material"

local sd = import_package "ant.settings".setting

local COBJ = rmat.cobject {
    bgfx = assert(bgfx.CINTERFACE) ,
    math3d = assert(math3d.CINTERFACE),
    encoder = assert(bgfx.encoder_get()),
}

local cmat_sys = ecs.system "cmaterial_system"

local function load_cmaterial(r, m, setting)
    local fx = assetmgr.load_fx(m.fx, setting)
    assert(fx.cs == nil, "need support compute shader")
    if fx.prog then
        log.warn("after using cmaterial, fx.prog should not create")
    end

    local prog = rmat.program(COBJ, fx.vs, fx.fs)
    local uniforms = prog:info()

    local properties = {}
    local isp = ecs.import.interface "ant.render|isystem_properties"
    for k in pairs(uniforms) do
        --TODO: need fix bgfx bug, @data is binding buffer name
        if not k:match "@data" then
            local p = m.properties[k] or isp.get(k)
            if p == nil then
                error(("shader need uniform:%s, but material file not provided"):format(k))
            end
    
            if p.stage then
                local tex = p.texture or p.image
                if tex then
                    properties[k] = {stage=p.stage, handle=tex.handle}
                end
            else
                if type(p[1]) == "table" then
                    local vv = {}
                    for _, v in ipairs(p) do
                        vv[#vv+1] = #v == 4 and math3d.vector(v) or math3d.matrix(v)
                    end
                    properties[k] = vv
                else
                    properties[k] = #p == 4 and math3d.vector(p) or math3d.matrix(p)
                end
            end
        end
    end

    if fx.setting.lighting == "on" then
        properties["b_light_info"]              = {stage=0, handle=nil, type='b'}
        if sd:data().graphic.lighting.cluster_shading ~= 1 then
            properties["b_light_grids"]         = {stage=0, handle=nil, type='b'}
            properties["b_light_index_lists"]   = {stage=0, handle=nil, type='b'}
        end
	end

    local mat = prog:material(m.state, properties)
    r.material = mat:instance()

    --TODO: need remove
    r.fx        = fx
    r.state     = m.state
end

function cmat_sys:component_init()

end

local function init_material(mm)
	if type(mm) == "string" then
		return assetmgr.resource(mm)
	end
	return ext_material.init(mm)
end

function cmat_sys:entity_init()
    for e in w:select "INIT cmaterial:in render_object:in material_setting?in " do
        local ro = e.render_object
        load_cmaterial(ro, init_material(e.cmaterial), e.material_setting)
    end
end