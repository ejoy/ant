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

local modifierevent = world:sub {"modifier"}
function modifier_sys:entity_ready()
    for _, m, desc in modifierevent:unpack() do
        local e <close> = w:entity(m.eid, "modifier:in")
        local mf = e.modifier
        mf.continue = true
        mf.keep = desc.forwards
        if m.anim_eid then
            if desc.name then
                iani.play(m.anim_eid, desc)
            else
                local anim <close> = w:entity(m.anim_eid)
                ika.play(anim, desc)
            end
        end
    end
end
function modifier_sys:exit()

end

local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

function imodifier.delete(m)
    if not m then
        return
    end
    local e <close> = w:entity(m.eid, "modifier:in")
    local mf = e.modifier
    if mf.target then
        mf:reset()
    end
    w:remove(m.eid)
end

function imodifier.set_target(m, target)
    if not m then
        return
    end
    local e <close> = w:entity(m.eid, "modifier:in")
    local mf = e.modifier
    if target == mf.target then
        return
    end
    local iv
    if mf.property then
        -- material
        if not target then
            return
        end
        local e <close> = w:entity(target, "material:in")
        local filename = e.material
        if not filename then
            return
        end
        local mtl = serialize.parse(filename, cr.read_file(filename))
        if not mtl.properties[mf.property] then
            return
        end
        iv = math3d.ref(math3d.vector(mtl.properties[mf.property]))
    end
    if mf.target then
        mf:reset()
    end
    mf.init_value = iv
    mf.target = target
end

function imodifier.create_mtl_modifier(target, property, keyframes, keep, foreupdate)
    local function get_value(ae, time)
        local e <close> = w:entity(target, "keyframe:in")
        local kfanim = e.keyframe
        return kfanim.play_state.current_value, kfanim.play_state.playing
    end

    local init_value
    if target then
        local e <close> = w:entity(target, "material:in")
        local filename = e.material
        local mtl = serialize.parse(filename, cr.read_file(filename))
        assert(mtl.properties[property])
        init_value = math3d.ref(math3d.vector(mtl.properties[property]))
    end

    local kfeid = ika.create(keyframes)

    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            name = "",
            scene = {
                parent = target
            },
            modifier = {
                target = target,
                continue = false,
                property = property,
                init_value = init_value,
                keep = keep,
                foreupdate = foreupdate,
                kfeid = kfeid,
                reset = function (self)
                    local e <close> = w:entity(self.target)
                    imaterial.set_property(e, self.property, self.init_value)
                end,
                update = function(self, time)
                    if not self.target then
                        return
                    end
                    if not self.foreupdate and not self.continue then
                        return
                    end
                    local value, running = get_value(self.kfeid, time)
                    local apply_value = value and math3d.vector(value) or self.init_value
                    if not running and not self.keep and not self.foreupdate then
                        apply_value = self.init_value
                    end
                    local e <close> = w:entity(self.target)
                    imaterial.set_property(e, self.property, apply_value)
                    self.continue = running
                end
            }
        }
    }
    local eid = ecs.create_entity(template)
    return {
        eid = eid,
        anim_eid = kfeid
    }
end

function imodifier.create_srt_modifier(target, group_id, generator, keep)
	local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            name = "",
            scene = {
                parent = target,
            },
            modifier = {
                target = target,
                continue = false,
                keep = keep,
                reset = function (self)
                    local e <close> = w:entity(self.target)
                    iom.set_srt_offset_matrix(e, mc.IDENTITY_MAT)
                end,
                update = function(self, time)
                    if not self.continue or not self.target then
                        return
                    end
                    local value, running = generator(time)
                    local apply_value = value
                    if not running and not self.keep then
                        apply_value = mc.IDENTITY_MAT
                    end
                    local e <close> = w:entity(self.target)
                    iom.set_srt_offset_matrix(e, apply_value)
                    self.continue = running
                end
            },
		},
    }
    return ecs.group(group_id):create_entity(template)
end

function imodifier.start(m, desc)
    world:pub {"modifier", m, desc}
end

function imodifier.stop(m)
    if not m then
        return
    end
    local e <close> = w:entity(m.eid, "modifier:in")
    e.modifier.continue = false
end

function imodifier.create_bone_modifier(target, group_id, filename, bone_name)
    local anim_prefab = ecs.create_instance(filename)
    return {
        eid = imodifier.create_srt_modifier(target, group_id, function (time)
            local anim <close> = w:entity(anim_prefab.tag["*"][1], "anim_ctrl:in skeleton:in")
            local pr = anim.anim_ctrl.pose_result
            return pr:joint(anim.skeleton._handle:joint_index(bone_name)), anim.anim_ctrl.play_state.play
        end),
        anim_eid = anim_prefab
    }
end

