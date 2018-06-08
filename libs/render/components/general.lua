local ecs = ...

local path = require "filesystem.path"
local fs_util = require "filesystem.util"
local asset = require "asset"

ecs.component "position"{
    v = {type="vector"}
}

ecs.component "rotation"{
    v = {type="vector"}
}

ecs.component "scale" {
    v = {type="vector"}
}

ecs.component "frustum" {
    isortho = false,
    n = 0.1,
    f = 10000,
    l = -1,
    r = 1,
    t = -1,
    b = 1,
}

ecs.component "viewid" {
    id = 0
}

ecs.component "mesh" {
	path = ""
}

ecs.component "material" {
	content = {
		type = "userdata",
		defatult = {
			{
				path = "",
				properties = {}
			}
		},
		save = function (v, arg)
			local t = {}
			for _, e in ipairs(v) do
				local tt = {}
				tt.path = e.path
				local properties = {}
				for k, p in pairs(e.properties) do					
					local type = v.type
					if type == "texture" then                        
						properties[k] = {path=v.path, type=type}
					else
						properties[k] = p
					end
				end
				tt.properties = properties
				table.insert(t, tt)
			end
			return t
		end,
		load = function (v, arg)
			assert(type(v) == "table")
            local t = {}
            for _, e in ipairs(v) do
                local ee = {}
                for k, v in pairs(e) do
                    local type = v.type
                    if type == "texture" then
                        assert(false, "Not implement")
                    else
                        ee[k] = v
                    end
                end
                table.insert(t, ee)
            end
            return t
		end
	}
}

ecs.component "can_render" {
	visible = true
}

ecs.component "name" {
    n = ""
}

ecs.component "can_select" {

}

ecs.component "last_render"{
    enable = true
}

ecs.component "control_state" {
    state = "camera"
}

ecs.component "hierarchy_parent" {
	eid = -1
}