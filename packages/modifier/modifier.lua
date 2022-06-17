local ecs 	= ...
local world = ecs.world
local w 	= world.w

local modifier_sys = ecs.system "modifier_system"
local imodifier = ecs.interface "imodifier"
local iani      = ecs.import.interface "ant.animation|ianimation"
local timer     = ecs.import.interface "ant.timer|itimer"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local ika       = ecs.import.interface "ant.animation|ikeyframe"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local math3d    = require "math3d"

function modifier_sys:init()

end

function modifier_sys:component_init()
    for e in w:select "INIT modifier:in" do

    end
end

function modifier_sys:update_modifier()
    local delta_time = timer.delta() * 0.001
    for e in w:select "modifier:in" do
        e.modifier:update(delta_time)
    end
end

function modifier_sys:exit()

end

local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

function imodifier.set_target(m, target)
    local mf = world:entity(m.eid).modifier
    if target == mf.target then
        return
    end
    if mf.target then
        mf:reset()
    end
    if mf.property then
        -- material
        local filename = world:entity(target).material
        if not filename then
            mf.target = nil
            return
        end
        local mtl = serialize.parse(filename, cr.read_file(filename))
        mf.init_value = math3d.ref(math3d.vector(mtl.properties[mf.property]))
    else
        -- srt
        mf.init_value = math3d.ref(math3d.matrix(world:entity(target).scene.srt))
    end
    mf.target = target
end

function imodifier.create_mtl_modifier(target, property, keyframes, keep)
    local ka = ika.create(keyframes)

    local function generator(time)
        local kfanim = world:entity(ka).keyframe
        return kfanim.play_state.current_value, kfanim.play_state.playing
    end

    local init_value
    if target then
        local filename = world:entity(target).material
        local mtl = serialize.parse(filename, cr.read_file(filename))
        init_value = math3d.ref(math3d.vector(mtl.properties[property]))
    end
    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            name = "",
            scene = {srt = {}},
            modifier = {
                target = target,
                continue = false,
                property = property,
                init_value = init_value,
                keep = keep,
                reset = function (self)
                    imaterial.set_property(world:entity(self.target), self.property, self.init_value)
                end,
                update = function(self, time)
                    if not self.continue or not self.target then
                        return
                    end
                    local value, running = generator(time)
                    local apply_value = math3d.vector(value)
                    if not running and not self.keep then
                        apply_value = self.init_value
                    end
                    imaterial.set_property(world:entity(self.target), self.property, apply_value)
                    self.continue = running
                end
            }
        }
    }
    local eid = ecs.create_entity(template)
    ecs.method.set_parent(eid, target)
    return {
        eid = eid,
        anim_eid = ka
    }
end

function imodifier.create_srt_modifier(target, generator, keep)
	local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            name = "",
            scene = {srt = {}},
            modifier = {
                target = target,
                continue = false,
                keep = keep,
                init_value = math3d.ref(math3d.matrix(world:entity(target).scene.srt)),
                reset = function (self)
                    iom.set_srt_matrix(world:entity(self.target), self.init_value)
                end,
                update = function(self, time)
                    if not self.continue or not self.target then
                        return
                    end
                    local value, running = generator(time)
                    local apply_value = math3d.mul(self.init_value, value)
                    if not running and not self.keep then
                        apply_value = self.init_value
                    end
                    iom.set_srt_matrix(world:entity(self.target), apply_value)
                    self.continue = running
                end
            },
		},
    }
    local eid = ecs.create_entity(template)
    ecs.method.set_parent(eid, target)
    return eid
end

function imodifier.start(m, desc)
    local mf = world:entity(m.eid).modifier
    mf.continue = true
    if m.anim_eid then
        if desc.name then
            iani.play(world:entity(m.anim_eid), desc)
        else
            ika.play(world:entity(m.anim_eid), desc)
        end
    end
end

function imodifier.stop(m)
    world:entity(m.eid).modifier.continue = false
end

function imodifier.create_bone_modifier(target, filename, bone_name)
    local anim_inst = ecs.create_instance(filename)
    return {
        eid = imodifier.create_srt_modifier(target, function (time)
            local anim = world:entity(anim_inst.tag["*"][2])
            local pr = anim.anim_ctrl.pose_result
            return pr:joint(anim.skeleton._handle:joint_index(bone_name)), anim.anim_ctrl._current.play_state.play
        end),
        anim_eid = anim_inst
    }
end

