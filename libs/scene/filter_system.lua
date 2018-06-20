local ecs = ...
local world = ecs.world

local mu = require "math.util"

local function push_primitive_in_filter(eid, filter)
    local e = world[eid]
    local can_render = e.can_render

    if can_render == nil or not can_render.visible then
        return 
	end
	
	local meshcomp = e.mesh	
	if meshcomp == nil then
		return 
	end

	local mesh = assert(meshcomp.assetinfo)
	
	local materialcontent = e.material.content
	assert(#materialcontent >= 1)

	local srt ={s=e.scale.v, r=e.rotation.v, t=e.position.v}

	local result = filter.result
	local mgroups = mesh.handle.group
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materialcontent[i] or materialcontent[1]
		local materialinfo = mc.materialinfo
		local properties = mc.properties

		table.insert(result, {
			eid = eid,
			mgroup = g,
			material = materialinfo,
			properties = properties,
			srt = srt,
		})
	end
end

--- scene filter system----------------------------------
local primitive_filter_sys = ecs.system "primitive_filter_system"

primitive_filter_sys.singleton "primitive_filter"
primitive_filter_sys.singleton "math_stack"

function primitive_filter_sys:update()
    local filter = self.primitive_filter
    filter.result = {}
    for _, eid in world:each("can_render") do
        push_primitive_in_filter(eid, filter)
    end
end

----for select filter system-------------------------------
local select_filter_sys = ecs.system "select_filter_system"

select_filter_sys.singleton "math_stack"
select_filter_sys.singleton "select_filter"

function select_filter_sys:update()
    local filter = self.select_filter
    filter.result = {}
    for _, eid in world:each("can_select") do        
        push_primitive_in_filter(eid, filter)
    end
end