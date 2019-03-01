local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

ecs.tag "hierarchy_tag"

ecs.component_alias("world_srt", "srt")
ecs.component_alias("hierarchy_transform", "transform")

ecs.component_alias("attach", "entityid")

local hierarchy_transform_result = ecs.singleton "hierarchy_transform_result"
function hierarchy_transform_result:init()

end

local testscene = ecs.system "test_scene"
testscene.singleton "event"
testscene.singleton "hierarchy_transform_result"

local function create_default_transform(parent, base, s, r, t, attach)
	return {
		parent = parent,
		attach = attach,
		base = base,
		s = s or {1, 1, 1, 0},
		r = r or {0, 0, 0, 0},
		t = t or {0, 0, 0, 1},
	}
end

local identity_matrix = {
	1, 0, 0, 0,
	0, 1, 0, 0,
	0, 0, 1, 0,
	0, 0, 0, 1,
}


function testscene:init()
	local material = {
		content = {
			{
				ref_path = {package="ant.resources", filename=fs.path "bunny.material"}
			}
		}
	}

	local hie_root = world:create_entity {				
		hierarchy_transform = create_default_transform(),
		name = "root",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level1_1 = world:create_entity {		
		hierarchy_transform = create_default_transform(hie_root),
		name = "level1_1",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level1_2 = world:create_entity {		
		hierarchy_transform = create_default_transform(hie_root),
		name = "level1_2",
		hierarchy_tag = true,
		main_viewtag = true,
	}

	local hie_level2_1 = world:create_entity {
		hierarchy_transform = create_default_transform(hie_level1_2),
		name = "level2_1",
		hierarchy_tag = true,
		main_viewtag = true,
	}


	local render_root = world:create_entity {
		transform = create_default_transform(nil, identity_matrix, nil, nil, nil, hie_root),
		name = "render_root",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "cube.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_level1_1 = world:create_entity {
		transform = create_default_transform(nil, identity_matrix, nil, nil, nil, hie_level1_1),
		name = "render_level1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_level1_2 = world:create_entity {
		transform = create_default_transform(nil, identity_matrix, nil, nil, nil, hie_level1_2),
		name = "render_level1_2",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}


	local render_level2_1 = world:create_entity {
		transform = create_default_transform(nil, identity_matrix, nil, nil, nil, hie_level2_1),
		name = "render_level2_eid1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	--[[
				render_root		hie_root
								/		\
							   /		 \
							  /		 	  \
							 /		 	   \
render_level1_1			hie_level1_1	hie_level1_2		render_level1_2
							/			 	 \
						   /				  \
						  /					   \
						render_child1 		hie_level2_1	render_level2_1
												/
											   /
										render_child2_1
	]]

	local render_child1 = world:create_entity{
		transform = create_default_transform(hie_level1_1),
		name = "render_child1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}

	local render_child2_1 = world:create_entity{
		transform = create_default_transform(hie_level2_1),		
		name = "render_child2_1",
		mesh = {
			ref_path = {package="ant.resources", filename=fs.path "sphere.mesh"},
		},
		material = material,
		can_render = true,
		main_viewtag = true,
	}
end

function testscene:post_init()
	for eid in world:each_new("hierarchy_transform") do
		self.event:new(eid, "hierarchy_transform")
	end

	for eid in world:each_new("transform") do
		self.event:new(eid, "transform")
	end
end

local scene_space = ecs.system "scene_space"
scene_space.singleton "event"

local function mark_children(marked, eid)
	local pid = world[eid].transform.parent
	if pid and marked[pid] then
		marked[eid] = pid
		return true
	end
	marked[eid] = false
	return false
end

local mark_mt = { __index = mark_children }

local function find_children(tree, eid)
	local _ = tree[eid]
end

local function tree_sort(tree)
	local r = {}

	local from = 1
	local to = 1
	-- find leaves
	local leaf = {}
	for eid, pid in pairs(tree) do
		if pid then
			if leaf[pid] then	-- fake leaf
				-- todo remove result
				for i = 1, to-1 do
					if r[i] == pid then
						to = to - 1
						r[i] = r[to]
						break
					end
				end
			end
			leaf[pid] = false
			if leaf[eid] == nil then
				leaf[eid] = true	-- mark leaf
				r[to] = eid
				to = to + 1
			end
		end
	end
	while to > from do
		local lb = from
		from = to
		for i = lb, to-1 do
			local pid = tree[r[i]]
			if pid and tree[pid] and not leaf[pid] then
				r[to] = pid
				to = to + 1
				leaf[pid] = true
			end
		end
	end
	return r
end

local function update_world(trans)
	local srt = ms:push_srt_matrix(trans)
	ms(trans.world, srt, trans.base, "*=")
end

local function handle_transform_events(events, comp)
	local handlers = {
		attach = function (comp, value)
		end,
		parent = function (comp, value)
		end,
		s = function (comp, value)
			ms(comp.s, value, "=")			
		end,
		r = function (comp, value)
			ms(comp.r, value, "=")			
		end,
		t = function (comp, value)
			ms(comp.s, value, "=")			
		end,
		base = function (comp, value)
			ms(comp.base, value, "=")			
		end,
	}

	for event, value in pairs(events) do
		local handler = handlers[event]
		if handler then
			handler(comp, value)
		else
			print("handler is not default in transform:", event)
		end
	end
end

function scene_space:event_changed()
	for eid, events in self.event:each("transform") do
		local e = world[eid]
		local trans = e.transform
		handle_transform_events(events, trans)

		local attacheid = trans.attach
		if attacheid then
			local attache = world[attacheid]
			local base = events['base']
			if base then
				attache.hierarchy_transform.watcher.base = base
			end
		end
	end

	local hierarchy_result = self.hierarchy_transform_result

	local tree = setmetatable({}, mark_mt)

	for eid, modify in self.event:each("hierarchy_transform") do
		local e = world[eid]
		e.hierarchy_transform = modify
		find_children(tree, eid)
	end

	if #tree > 0 then
		local result = tree_sort(tree)
		
		for i=#result, 1, -1 do
			local eid = result[i]
			local e = world[eid]
			local t = e.transform
			update_world(e.transform)
			local peid = e.parent 
	
			if peid then
				local parent = world[peid]
				local pt = parent.transform
				ms(t.world, pt.world, t.world, "*=")				
			end

			hierarchy_result[eid] = t.world
		end

	end

	
end