local ecs 	= ...
local world = ecs.world
local w 	= world.w

local assetmgr  = import_package "ant.asset"
local serialize = import_package "ant.serialize"

local modifier_sys = ecs.system "modifier_system"
local iani      = ecs.require "ant.animation|state_machine"
local timer     = ecs.require "ant.timer|timer_system"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local ika       = ecs.require "ant.animation|keyframe"
local imaterial = ecs.require "ant.asset|material"
local mathpkg	= import_package "ant.math"
local mc	= mathpkg.constant
local math3d    = require "math3d"

local imodifier = {}
local auto_destroy_map = {}
function modifier_sys:init()

end

function modifier_sys:component_init()
    for e in w:select "INIT modifier:in" do

    end
end

local modifierevent = world:sub {"modifier"}
function modifier_sys:update_modifier()
    for _, m, desc in modifierevent:unpack() do
        local e <close> = world:entity(m.eid, "modifier:in")
        if not e then
            goto continue
        end
        local mf = e.modifier
        mf.continue = true
        mf.keep = desc.forwards
        mf.destroy = desc.destroy
        mf.init_srt = desc.init_srt
        if m.anim_eid then
            if desc.name then
                iani.play(m.anim_eid, desc)
            else
                local anim <close> = world:entity(m.anim_eid)
                ika.play(anim, desc)
            end
        end
        ::continue::
    end
    local delta_time = timer.delta() * 0.001
    local to_remove = {}
    for e in w:select "modifier:in eid:in" do
        local rm = e.modifier:update(delta_time)
        if rm then
            to_remove[#to_remove + 1] = e.eid
        end
    end
    for _, eid in ipairs(to_remove) do
        imodifier.delete(auto_destroy_map[eid])
        auto_destroy_map[eid] = nil
    end
end


function modifier_sys:entity_ready()

end
function modifier_sys:exit()

end

local function read_file(filename)
    local f
    if string.sub(filename, 1, 1) == "/" then
        f = assert(io.open(assetmgr.compile(filename), "rb"))
    else
        f = assert(io.open(filename, "rb"))
    end
    local c = f:read "a"
    f:close()
    return c
end

function imodifier.delete(m)
    if not m then
        return
    end
    local e <close> = world:entity(m.eid, "modifier:in")
    local mf = e.modifier
    if mf.target then
        mf:reset()
    end
    w:remove(m.eid)
    if type(m.anim_eid) == "table" then
        world:remove_instance(m.anim_eid)
    else
        w:remove(m.anim_eid)
    end
end

function imodifier.set_target(m, target)
    if not m then
        return
    end
    local e <close> = world:entity(m.eid, "modifier:in")
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
        local me <close> = world:entity(target, "material:in")
        local filename = me.material
        if not filename then
            return
        end
        local mtl = serialize.parse(filename, read_file(filename))
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
    local function get_value(kfe, time)
        local e <close> = world:entity(kfe, "keyframe:in")
        local kfanim = e.keyframe
        return kfanim.play_state.current_value, kfanim.play_state.playing
    end

    local init_value
    if target then
        local e <close> = world:entity(target, "material:in")
        local filename = e.material
        if string.find(filename, ".glb|") then
            filename = filename .. "/main.cfg"
        end
        local mtl = serialize.parse(filename, read_file(filename))
        assert(mtl.properties[property])
        init_value = math3d.ref(math3d.vector(mtl.properties[property]))
    end

    local kfeid = ika.create(keyframes)

    local template = {
		policy = {
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            scene = {},
            modifier = {
                target = target,
                continue = false,
                property = property,
                init_value = init_value,
                keep = keep,
                foreupdate = foreupdate,
                kfeid = kfeid,
                reset = function (self)
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    imaterial.set_property(e, self.property, self.init_value)
                end,
                update = function(self, time)
                    if not self.target or (not self.foreupdate and not self.continue) then
                        return
                    end
                    local value, running = get_value(self.kfeid, time)
                    local apply_value = value and math3d.vector(value) or self.init_value
                    if not running and not self.keep and not self.foreupdate then
                        apply_value = self.init_value
                    end
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    imaterial.set_property(e, self.property, apply_value)
                    self.continue = running
                end
            }
        }
    }
    return {
        eid = world:create_entity(template),
        anim_eid = kfeid
    }
end

function imodifier.create_srt_modifier(target, group_id, generator, keep, foreupdate)
    local anim_eid
    if type(generator) == "table" then
        anim_eid = ika.create(generator)
        local function get_value(kfe, time)
            local e <close> = world:entity(kfe, "keyframe:in")
            local kfanim = e.keyframe
            return kfanim.play_state.current_value, kfanim.play_state.playing
        end
        generator = function(time)
            local srt, running = get_value(anim_eid, time)
            srt = srt or {1, 0, 0, 0, 0, 0, 0}
            return math3d.matrix({s = srt[1],
                r = math3d.quaternion{math.rad(srt[2]), math.rad(srt[3]), math.rad(srt[4])},
                t = {srt[5], srt[6], srt[7]}}), running
        end
    end
    
	local template = {
        group = group_id,
		policy = {
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            scene = {},
            modifier = {
                target = target,
                continue = false,
                keep = keep,
                foreupdate = foreupdate,
                reset = function (self)
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    if not self.init_srt then
                        iom.set_srt_offset_matrix(e, mc.IDENTITY_MAT)
                    else
                        iom.set_rotation(e, math3d.quaternion(self.init_srt.r))
                        iom.set_position(e, math3d.vector(self.init_srt.t))
                    end
                end,
                update = function(self, time)
                    if not self.target or (not self.foreupdate and not self.continue) then
                        return
                    end
                    local value, running = generator(time)
                    local apply_value = value
                    if not running and not self.keep and not self.foreupdate then
                        apply_value = mc.IDENTITY_MAT
                    end
                    local e <close> = world:entity(self.target)
                    if not e then
                        return true
                    end
                    if not self.init_srt then
                        iom.set_srt_offset_matrix(e, apply_value)
                    else
                        iom.set_srt_matrix(e, apply_value)
                    end
                    self.continue = running
                    if not running and self.destroy then
                        return true
                    end
                end
            },
		},
    }
    return {
        eid = world:create_entity(template),
        anim_eid = anim_eid
    }
end

function imodifier.start(m, desc)
    if not m then
        return
    end
    world:pub {"modifier", m, desc}
end

function imodifier.start_bone_modifier(target, group_id, filename, bone_name, desc)
    local m = imodifier.create_bone_modifier(target, group_id, filename, bone_name)
    desc.destroy = true
    auto_destroy_map[m.eid] = m
    imodifier.start(m, desc)
end

function imodifier.stop(m)
    if not m then
        return
    end
    local e <close> = world:entity(m.eid, "modifier:in")
    e.modifier.continue = false
end

function imodifier.create_bone_modifier(target, group_id, filename, bone_name)
    local anim_prefab = world:create_instance {
		prefab = filename,
	}
    local modifier = imodifier.create_srt_modifier(target, group_id, function (time)
            for _, e in ipairs(anim_prefab.tag["*"]) do
                local anim <close> = world:entity(e, "anim_ctrl?in skeleton?in")
                if anim.anim_ctrl and anim.skeleton then
                    return anim.anim_ctrl.pose_result:joint(anim.skeleton._handle:joint_index(bone_name)), anim.anim_ctrl.play_state.play
                end
            end
        end)
    modifier.anim_eid = anim_prefab
    return modifier
end

return imodifier
