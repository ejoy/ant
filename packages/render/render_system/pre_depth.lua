local ecs = ...
local world = ecs.world

local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local bgfx      = require "bgfx"

local pre_depth_material
local pre_depth_skinning_material

local function which_material(skinning)
	return skinning and pre_depth_skinning_material or pre_depth_material
end


local s = ecs.system "pre_depth_primitive_system"
local w = world.w

function s:init()
    if not irender.use_pre_depth() then
        return
    end

    local pre_depth_material_file<const> 	= "/pkg/ant.resources/materials/predepth.material"
    pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="inv_z"})
    pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="inv_z", skinning="GPU"})
end

local function check_set_pre_depth_state(state)
    local ss = bgfx.parse_state(state)
    ss.WRITE_MASK = "Z"
    return bgfx.make_state(ss)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
function s:data_changed()
    if irender.use_pre_depth() then
        for msg in vr_mb:each() do
            local vr = msg[3]
            local dq = w:singleton("pre_depth_queue", "render_target:in")
            local dqvr = dq.render_target.view_rect
            --have been changed in viewport detect
            assert(vr.w == dqvr.w and vr.h == dqvr.h)
            if vr.x ~= dqvr.x or vr.y ~= dqvr.y then
                irq.set_view_rect("pre_depth_queue", vr)
            end
        end
    end
end

local material_cache = {__mode="k"}

function s:end_filter()
    if irender.use_pre_depth() then
        for e in w:select "filter_result:in render_object:in filter_material:in skinning?in" do
            local m = assert(which_material(e.skinning))
            local mi = m.material
            local fr = e.filter_result
            local qe = w:singleton("pre_depth_queue", "primitive_filter:in")
            for _, fn in ipairs(qe.primitive_filter) do
                if fr[fn] then
                    e.filter_material[fn] = {
                        material = irender.check_copy_material(mi, e.render_object.material, material_cache),
                        fx = m.fx,
                    }
                end
            end
        end
    end
end
