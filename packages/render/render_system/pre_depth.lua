local ecs = ...
local world = ecs.world

local irender   = ecs.import.interface "ant.render|irender"
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
    pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="linear"})
    pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="linear", skinning="GPU"})
end

local function check_set_pre_depth_state(state)
    local ss = bgfx.parse_state(state)
    ss.WRITE_MASK = "Z"
    return bgfx.make_state(ss)
end

function s:end_filter()
    if irender.use_pre_depth() then
        for e in w:select "filter_result:in render_object:in filter_material:in skinning?in" do
            local m = assert(which_material(e.skinning))
            local fr = e.filter_result
            local state = e.render_object.state
            local qe = w:singleton("pre_depth_queue", "primitive_filter:in")
            for _, fn in ipairs(qe.primitive_filter) do
                if fr[fn] then
                    e.filter_material[fn] = {
                        fx          = m.fx,
                        properties  = m.properties,
                        state       = check_set_pre_depth_state(state)
                    }
                end
            end
        end
    end
end
