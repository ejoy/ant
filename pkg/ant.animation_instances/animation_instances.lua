local ecs   = ...
local world = ecs.world
local w     = world.w
local bgfx  = require "bgfx"
local math3d= require "math3d"

local anibaker  = ecs.require "animation_baker"

local hwi       = import_package "ant.hwi"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local irender   = ecs.require "ant.render|render"
local icompute  = ecs.require "ant.render|compute.compute"
local imesh     = ecs.require "ant.asset|mesh"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"
local anibaker_sys = ecs.system "animation_baker_system"
function anibaker_sys:entity_remove()
    for e in w:select "REMOVED animation_instances:in" do
        if e.animation_instances.framehandle then
            bgfx.destroy(e.animation_instances.framehandle)
            e.animation_instances.framehandle = nil
        end
    end
end

local append_frame, finish_frame; do
    local function pack_uint(uint)
        assert(uint.n == 4)
        local r = ("I"):pack(uint[1]|uint[2]<<8|uint[3]<<16|uint[4]<<24)
        uint.n = 1
        return r
    end

    --must init uint vector with 4 values
    local uint = {n=1, 0, 0, 0, 0}

    function append_frame(uint_frames, f)
        uint[uint.n] = f
        if uint.n == 4 then
            uint_frames[#uint_frames+1] = pack_uint(uint)
        else
            uint.n = uint.n + 1
        end
    end

    function finish_frame(uint_frames)
        for i=uint.n, 4 do
            uint[i] = 0
        end
        uint.n = 4
        uint_frames[#uint_frames+1] = pack_uint(uint)
    end
end

local function pack_buffers(instances)
    local transforms = {}
    local uint_frames = {}

    for _, i in ipairs(instances) do
        local m = math3d.transpose(math3d.matrix(i))
        local c0, c1, c2, c3 = math3d.index(m, 1, 2, 3, 4)
        assert(math3d.isequal(c3, mc.ZERO_PT))

        transforms[#transforms+1] = ("%s%s%s"):format(math3d.serialize(c0), math3d.serialize(c1), math3d.serialize(c2))

        append_frame(uint_frames, assert(i.frame))
    end

    finish_frame(uint_frames)
    return table.concat(transforms, ""), table.concat(uint_frames, "")
end

local function create_frame_buffer(framebuffer)
    assert(#framebuffer > 0)
    return bgfx.create_index_buffer(irender.align_buffer(framebuffer), "dr")
end

local function update_compute_properties(material, ai, di)
    local mesh = ai.mesh
    material.u_mesh_param        = math3d.vector(mesh.vbnum, mesh.ibnum, 0, di.instance_buffer.num)
    local frame = ai.frame
    material.u_mesh_param1       = math3d.vector(frame.offset, frame.num, 0, 0)
    material.b_instance_frames   = frame.handle
    material.b_indirect_buffer   = di.handle
end

local skinning_viewid<const> = hwi.viewid_get "skinning"

local DISPATCH_SIZE<const> = 64

local function dispatch_(ce, ai, di)
    update_compute_properties(ce.dispatch.material, ai, di)
    ce.dispatch.size[1] = di.instance_buffer.num // DISPATCH_SIZE+1
    icompute.dispatch(skinning_viewid, ce.dispatch)
end

local function dispatch(compute, ai, di)
    dispatch_(world:entity(compute, "dispatch:in"), ai, di)
end

local MAX_INSTANCES<const> = 1024

local function default_instances(num)
    local instances = {}
    for i=1, num do
        instances[i] = {
            frame = i-1
        }
    end
    return instances
end

local function check_instances(numinstance, instances)
    if nil == numinstance and nil == instances then
        error "one of 'numinstance' or 'instances' argument should be defined"
    end

    if numinstance and instances and numinstance ~= #instances then
        error(("'numinstance':%d should equal to '#instances':%d number"):format(numinstance, #instances))
    end

    numinstance = numinstance or #instances
    instances   = instances or default_instances(numinstance)

    return numinstance, instances
end

local iai = {}
function iai.create(prefab, framenum, numinstance, instances)
    numinstance, instances = check_instances(numinstance, instances)

    local anio, mesho   = anibaker.init(prefab)
    local meshset       = anibaker.bake(anio, mesho, framenum)

    local instancebuffer, animationframe_buffer = pack_buffers(instances)
    local ani = {}
    for n, result in pairs(meshset) do
        ani[n] = {
            render = world:create_entity{
                policy = {
                    "ant.render|simplerender",
                    "ant.render|draw_indirect",
                    "ant.animation_instances|animation_instances",
                },
                data = {
                    material        = mesho.material,
                    scene           = mesho.scene,
                    draw_indirect   = {
                        instance_buffer = {
                            memory  = instancebuffer,
                            flag    = "r",
                            layout  = "t45NIf|t46NIf|t47NIf",    --for matrix3x4
                            num     = numinstance,
                            size    = MAX_INSTANCES,
                        }
                    },
                    mesh_result     = imesh.init_mesh(result.mesh),
                    animation_instances = {
                        instances   = instances,
                        mesh        = {
                            vbnum   = mesho:numv(),
                            ibnum   = mesho:numi(),
                        },
                        frame       = {
                            handle = create_frame_buffer(animationframe_buffer),
                            offset = 0,
                            num    = framenum,
                            duration = result.animation_duration,
                            bakestep_ratio = result.bakestep_ratio,
                        },
                    },
                    visible_masks   = "main_view|cast_shadow",
                    visible         = true,
                }
            },
            compute = world:create_entity{
                policy = {
                    "ant.render|compute"
                },
                data = {
                    material = "/pkg/ant.resources/materials/animation_dispatch.material",
                    dispatch = {
                        size = {1, 1, 1},
                    },
                    on_ready = function (e)
                        w:extend(e, "dispatch:in")
                        local re = world:entity(ani[n].render, "animation_instances:in draw_indirect:in")
                        dispatch_(e, re.animation_instances, re.draw_indirect)
                    end,
                }
            }
        }
    end

    return ani
end

local function check_recreate_frame_buffer(ai, framebuffer)
    if ai.frame.handle then
        bgfx.destroy(ai.frame.handle)
    end

    ai.frame.handle = create_frame_buffer(framebuffer)
end

local function pack_frame_buffer(ai, frames)
    local instances = ai.instances
    assert(#instances == #frames)
    local uint_frames = {}
    for idx, f in ipairs(frames) do
        instances[idx].frame = f
        append_frame(uint_frames, f)
    end
    finish_frame(uint_frames)
    return table.concat(uint_frames, "")
end

function iai.update_frames(abo, frames)
    local re = world:entity(abo.render, "animation_instances:in draw_indirect:in")
    if #frames ~= idi.instance_num(re) then
        error(("frames number:%d should equal instance buffer num:%d, or use update_instances instead"):format(#frames, idi.instance_num(re)))
    end

    local ai = re.animation_instances
    check_recreate_frame_buffer(ai, pack_frame_buffer(ai, frames))

    dispatch(abo.compute, ai, re.draw_indirect)
end

function iai.update_instances(abo, instances)
    local re = world:entity(abo.render, "animation_instances:in draw_indirect:in")
    local ai = re.animation_instances
    ai.instances = instances

    local instancebuffer, framebuffer = pack_buffers(instances)
    idi.update_instance_buffer(re, instancebuffer, #instances)
    check_recreate_frame_buffer(ai, framebuffer)

    dispatch(abo.compute, re.animation_instances, re.draw_indirect)
end

function iai.update_offset(abo, offset)
    local re = world:entity(abo.render, "animation_instances:in draw_indirect:in")
    local frame = re.animation_instances.frame
    if offset < 0 or offset >= frame.num then
        error(("'offset':%d should lower than 'frame.num': %d"):format(offset, frame.num))
    end
    frame.offset = offset
    dispatch(abo.compute, re.animation_instances, re.draw_indirect)
end

function iai.destroy(abo)
    for _, o in pairs(abo) do
        w:remove(o.render)
        w:remove(o.compute)
    end
end

return iai