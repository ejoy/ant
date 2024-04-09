local ecs = ...
local world = ecs.world
local w = world.w
local hwi       = import_package "ant.hwi"
local bgfx      = require "bgfx"
local imaterial = ecs.require "ant.render|material"
local ivr2d = ecs.require "ant.render|2d.viewrect2d"
local dynamic2d_sys = ecs.system "dynamic2d_system"
local assetmgr  = import_package "ant.asset"
local ltask = require "ltask"
local irender   = ecs.require "ant.render|render"
local imesh 	= ecs.require "ant.asset|mesh"
local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local MESH		= world:clibs "render.mesh"
local idq = {}
local fxaa_viewid<const>      = hwi.viewid_get "fxaa"

local function get_memory(width, height, clear)
    local t = {}
    for i = 1, width do
        for j = 1, height do
            for k = 1, #clear do
                t[#t+1] = clear[k]
            end
        end
    end
    return bgfx.memory_buffer("bbbb", t)
end

local function update_ro(ro, m)
	local vb = m.vb
	MESH.set(ro.mesh_idx, "vb0", vb.start, vb.num, vb.handle)

	local vb2 = m.vb2
	if vb2 then
		MESH.set(ro.mesh_idx, "vb1", vb2.start, vb2.num, vb2.handle)
	end

	local ib = m.ib
	if ib then
		MESH.set(ro.mesh_idx, "ib", ib.start, ib.num, ib.handle)
	end
end

function idq.update_pixels(eid, pixels, width, height)
    local de = world:entity(eid, "dynamicquad:update")
    local dq = de.dynamicquad
    local id = dq.id
    if (width and width ~= dq.width) or (height and height ~= dq.height) then
        w:extend(de, "viewrect2d:update mesh_result?update render_object:update")
        dq.width, dq.height = width, height
        de.viewrect2d = {
            x=0, y=0, w=width, h=height
        }
        imesh.delete_mesh(de.mesh_result)
        de.mesh_result = ivr2d.create_viewrect2d_mesh(de.viewrect2d)
        update_ro(de.render_object, de.mesh_result)
    end

    local handle = ltask.call(ServiceResource, "texture_content", id).handle

    if pixels then
        for _, pixel in ipairs(pixels) do
            local pos, value = pixel.pos, pixel.value
            local px, py = pos.x, pos.y
            assert(px >= 1 and px <= dq.tw and py >= 1 and py <= dq.th)
            local pitch = (py - 1) * dq.tw + px - 1
            dq.memory[pitch*4 + 1] = ("BBBB"):pack(table.unpack(value))
        end 
    end
    
    bgfx.update_texture2d(handle, 0, 0, 0, 0, dq.tw, dq.th, dq.memory)
    dq.handle = handle
end

function dynamic2d_sys:init_world()
    RENDER_ARG = irender.pack_render_arg("fxaa_queue", fxaa_viewid)
end

function dynamic2d_sys:render_submit()
    for e in w:select "dynamicquad:in eid:in visible?in" do
        if e.visible then
            irender.draw(RENDER_ARG, e.eid) 
        end
    end
end

function dynamic2d_sys:component_init()
    for e in w:select "INIT dynamicquad:in viewrect2d?out dynamicquad_ready?out eid:in" do
        local dq = e.dynamicquad
        local tex = assetmgr.resource(dq.texture)
        local id, tw, th = tex.id, tex.texinfo.width, tex.texinfo.height
        local clear = dq.clear or {0, 0, 0, 0}
        if (not dq.width) or (not dq.height) then
            dq.width, dq.height = tw, th
        end
        e.viewrect2d = {
            x=0, y=0, w=dq.width, h=dq.height
        }
        e.dynamicquad_ready = true
        local memory = get_memory(tw, th, clear)
        dq.id, dq.tw, dq.th, dq.memory = id, tw, th, memory
    end

end

function dynamic2d_sys:entity_ready()
    for e in w:select "dynamicquad_ready:update dynamicquad:in filter_material:in" do
        local dq = e.dynamicquad
        local id, tw, th, memory = dq.id, dq.tw, dq.th, dq.memory
        local handle = ltask.call(ServiceResource, "texture_content", id).handle
        dq.handle = handle
        bgfx.update_texture2d(handle, 0, 0, 0, 0, tw, th, memory)
        imaterial.set_property(e, "s_basecolor", id)
    end
end

function dynamic2d_sys:entity_remove()
    for e in w:select "REMOVED dynamicquad:in" do
        bgfx.destroy(e.dynamicquad.handle)
    end
end

return idq