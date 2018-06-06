local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"
local build_system = ecs.system "build_hierarchy_system"
build_system.singleton "math_stack"
local mu = require "math.util"

local function update_child_srt(ms, e, srt, node)
    local rot = ms({type="q", table.unpack(node.r)}, "eT")
    rot[1], rot[2] = rot[2], rot[1]

	local localsrt = mu.srt(ms, node.s, rot, node.t);
	local s, r, t = ms(localsrt, srt, "*~PPP");
	ms(e.scale.v, s, "=", e.rotation.v, r, "=", e.position.v, t, "=")
end

local function update_hierarchy_entiy(ms, h_entity)
	
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

local function build(ms, eid)
	local e = world[eid]
	if e.editable_hierarchy then
		if e.hierarchy == nil then
			world:add_component(eid, "hierarchy")
		end

		local root = assert(e.editable_hierarchy.root)
		e.hierarchy.builddata = assert(hierarchy_module.build(root))
		update_hierarchy_entiy(ms, e)

		local hie_np = e.hierarchy_name_mapper
		if hie_np then
			local namemapper = hie_np.v
			for _, ceid in pairs(namemapper) do
				build(ms, ceid)
			end
		end
	end
end

local function is_eid_in_tree(eid, tree)
	if tree == nil or next(tree) == nil then
		return false
	end

	for _, ceid in ipairs(tree) do
		if ceid == eid then
			return true
		end
	end

	return is_eid_in_tree(eid, tree.children)
end

local function build_hierarchy_update_tree(eid, branch, tree)
	if is_eid_in_tree(eid, tree) then
		return 
	end

	local e = world[eid]
	local hie_np = e.hierarchy_name_mapper
	if hie_np then
		local mapper = hie_np.v
		table.insert(branch, eid)
		
		for _, ceid in pairs(mapper) do
			if branch.children == nil then
				branch.children = {}
			end

			build_hierarchy_update_tree(ceid, branch.children, tree)
		end
	end
end

local function rebuild_hierarchy(ms, iterop)
	local tree = {}
	for _, eid in iterop() do
		build_hierarchy_update_tree(eid, tree, tree)
	end

	for _, eid in ipairs(tree) do	-- only first node
		build(ms, eid)
	end
end

function build_system:init()
	rebuild_hierarchy(self.math_stack, function ()
		return world:each("editable_hierarchy") end)
end

function build_system.notify:rebuild_hierarchy(set)
	rebuild_hierarchy(self.math_stack, function () return ipairs(set) end)
end