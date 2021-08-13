local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"

local irender   = world:interface "ant.render|irender"

local function can_write_depth(state)
	local s = bgfx.parse_state(state)
	local wm = s.WRITE_MASK
	return wm == nil or wm:match "Z"
end


local pre_depth_material
local pre_depth_skinning_material

local function which_material(eid)
	return world[eid].skinning_type == "GPU" and pre_depth_skinning_material or pre_depth_material
end


local s = ecs.system "pre_depth_primitive_system"
local w = world.w

function s:init()
    local pre_depth_material_file<const> 	= "/pkg/ant.resources/materials/predepth.material"
    pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="linear"})
    pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="linear", skinning="GPU"})
end

function s:end_filter()
    for e in w:select "fitler_result:in render_object:in eid:in filter_material:in" do
        local m = assert(which_material(e.eid))
        local fr = e.filter_result
        local state = e.render_object.state
        for qe in w:select "pre_depth_queue filter_names:in" do
            for _, fn in ipairs(qe.filter_names) do
                if fr[fn] then
                    e.filter_material[fn] = {
                        fx          = m.fx,
                        properties  = m.properties,
                        state       = irender.check_primitive_mode_state(state, m.state),
                    }
                end
            end
        end
    end
end
