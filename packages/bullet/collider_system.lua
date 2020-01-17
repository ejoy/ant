local ecs = ...
local world = ecs.world

local ms          = import_package "ant.math".stack
local bullet      = require "bullet"
local physicworld = bullet.world_create()

local function shape_delete(shape)
	if shape.handle then
		bullet.shape_destroy(shape.handle)
	end
end

local p = ecs.component "plane_shape"
	.origin "position"
	.normal "real[3]" {0, 1, 0}
	.distance "real" (1)
p.delete = shape_delete
function p:init()
	self.handle = bullet.shape_create_plane(self.normal, self.distance)
	return self
end

local s = ecs.component "sphere_shape"
	.radius "real" (1)
	.origin "position"
s.delete = shape_delete
function s:init()
	self.handle = bullet.shape_create_sphere(self.radius)
	return self
end

local b = ecs.component "box_shape"
	.origin "position"
	.size "real[3]" {1, 1, 1}
b.delete = shape_delete
function b:init()
	self.handle = bullet.shape_create_box(self.size)
	return self
end

local c = ecs.component "capsule_shape"
	.origin "position"
	.radius "real" (1)
	.height "real" (1)
	.axis 	"string" "Y"
c.delete = shape_delete
function c:init()
	self.handle = bullet.shape_create_capsule(self.radius, self.height, self.axis)
	return self
end

local C = ecs.component "compound_shape"
	.origin "position"
	["opt"].plane "plane_shape[]"
	["opt"].sphere "sphere_shape[]"
	["opt"].box "box_shape[]"
	["opt"].capsule "capsule_shape[]"
	["opt"].compound "compound_shape[]"

function C:init()
	self.handle = bullet.shape_create_compound()
	local function check_add_child(shape)
		if not shape then
			return
		end
		for _, sh in ipairs(shape) do
			bullet.shape_compound_add(self.handle, sh.handle, sh.origin)
		end
	end
	check_add_child(self.plane)
	check_add_child(self.shape)
	check_add_child(self.box)
	check_add_child(self.capsule)
	check_add_child(self.compound)
	return self
end

C.delete = shape_delete

local collcomp = ecs.component "collider"
	["opt"].user_idx "int"
	["opt"].plane "plane_shape"
	["opt"].sphere "sphere_shape"
	["opt"].box "box_shape"
	["opt"].capsule "capsule_shape"
	["opt"].compound "compound_shape"

function collcomp:init()
	local function add_shape(shape)
		if not shape then
			return
		end
		if self.handle then
			error "collider can only have one shape"
		end
		self.center = shape.origin
		self.handle = physicworld:object_create(shape.handle)
	end
	add_shape(self.plane)
	add_shape(self.sphere)
	add_shape(self.box)
	add_shape(self.capsule)
	add_shape(self.compound)
	if not self.handle then
		error "shape cannot be empty"
	end
	return self
end

function collcomp:delete()
	if self.handle then
		physicworld:object_destroy(self.handle)
	end
end

local cp = ecs.policy "collider"
cp.require_component "transform"
cp.require_component "collider"
cp.require_system "ant.bullet|collider_system"

local cp = ecs.policy "collider.character"
cp.require_policy "collider"
cp.require_system "ant.bullet|character_collider_system"

local math3d_adapter = require "math3d.adapter"
local mathadapter_util = import_package "ant.math.adapter"
mathadapter_util.bind("bullet", function ()
	local bw_mt 			   = getmetatable(physicworld)
	bw_mt.object_set_transform = math3d_adapter.matrix(ms, bw_mt.object_set_transform, 3)
	bw_mt.ray_test		 	   = math3d_adapter.vector(ms, bw_mt.ray_test, 2, 3)
	bw_mt.contact_test		   = math3d_adapter.vector(ms, bw_mt.contact_test, 3)
	bullet.shape_compound_add  = math3d_adapter.vector(ms, bullet.shape_compound_add, 3)
end)

local m = ecs.interface "collider"
m.require_system "collider_system"

function m.test(e, srt)
	local collider = e.collider
	if not collider then
		return false
	end
	local mat = ms:add_translate(ms:srtmat(srt), e.collider.center)
	return physicworld:contact_test(collider.handle, mat)
end

local collider_mb = world:sub {"component_register", "collider"}

local collider_sys = ecs.system "collider_system"

function collider_sys:data_changed()
    for msg in collider_mb:each() do
        local eid = msg[3]
        local e = world[eid]
        local collider = e.collider
        physicworld:object_set_useridx(collider.handle, eid)
        collider.user_idx = eid
    end
end

function collider_sys:update_collider_transform()
    for _, eid in world:each "collider" do
        local e = world[eid]
        -- TODO: world transform will not correct when this entity attach on hierarchy tree
        -- we need seprarte update transform from primitive_filter_system
        local mat = ms:add_translate(e.transform.world, e.collider.center)
        physicworld:object_set_transform(e.collider.handle, mat)
    end
end

local char_sys = ecs.system "character_collider_system"
char_sys.require_system "collider_system"

local character_motion = world:sub {"character_motion"}
local character_spawn = world:sub {"component_register", "character"}

local function update_collider(eid)
    local e = world[eid]
    local colliderobj = e.collider.handle
    local aabbmin, aabbmax = physicworld:object_get_aabb(colliderobj)
    local center = ms({0.5}, aabbmax, aabbmin, "+*T")
    local at = ms({center[1], aabbmin[2] - 3, center[3], 1.0}, "P")
    local hit, result = physicworld:ray_test(ms(center, "P"), at)
    if hit then
        world:pub {"ray_cast_hitted", eid, result}
        ms(e.transform.t, result.hit_pt_in_WS, "=")
    end
end

function char_sys:update_collider()
    for _, _, eid in character_spawn:unpack() do
        update_collider(eid)
    end
    for _, eid in character_motion:unpack() do
        update_collider(eid)
    end
end
