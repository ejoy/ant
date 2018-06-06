local ecs = ...
local world = ecs.world
local hierarchy_module = require "hierarchy"
local mu = require "math.util"

local h = ecs.component "hierarchy" {
    --init from serialize or build from editable_hierarchy component in runtime
    builddata = {
        type = "userdata", 
        save = function(v, arg)
            assert(type(v) == "userdata")

            local t = {}
            for _, node in ipairs(v) do
                table.insert(t, node)
            end

            return t
        end,
        load = function(v, arg)
            assert(type(v) == "table")
            return hierarchy_module.build(v)
        end
    }  
}

ecs.component "hierarchy_name_mapper"{
    v = {
        type = "userdata", 
        save = function(v, arg)
            assert(type(v) == "table")
            local t = {}
            for k, eid in pairs(v) do
                assert(type(eid) == "number")
                local e = world[eid]
                local seri = e.serialize
                if seri then
                    t[k] = seri.uuid
                end
            end
            return t
        end,
        load = function(v, arg)
            assert(type(v) == "table")
            return v
        end
    }
}


--- hierarchy update system -----------------------------
local hierarchy_update_sys = ecs.system "hierarchy_update_system"

hierarchy_update_sys.singleton "math_stack"

local function update_child_srt(ms, e, srt, node)
    local rot = ms({type="q", table.unpack(node.r)}, "eT")
    rot[1], rot[2] = rot[2], rot[1]

	local localsrt = mu.srt(ms, node.s, rot, node.t);
	local s, r, t = ms(localsrt, srt, "*~PPP");
	ms(e.scale.v, s, "=", e.rotation.v, r, "=", e.position.v, t, "=")
end

function hierarchy_update_sys.notify:hierarchy_changed(set)
    local ms = self.math_stack
	for _, h_eid in ipairs(set) do		
		local h_entity = assert(world[h_eid])
		local hierarchy = assert(h_entity.hierarchy)
	
		local rootsrt = mu.srt_from_entity(ms, h_entity)
        local builddata = hierarchy.builddata

        local mapper = h_entity.hierarchy_name_mapper.v
        for _, node in ipairs(builddata) do
			local name = node.name
            local c_eid = mapper[name]                
			local c_entity = world[c_eid]

			if c_entity then				
				update_child_srt(ms, c_entity, rootsrt, node)
            else
                error(string.format("not found entity by hierarchy name mapper, name is : %s", name))
            end
        end
    end  
end