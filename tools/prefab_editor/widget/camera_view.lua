local ecs   = ...
local world = ecs.world
local w     = world.w

local uiproperty    = require "widget.uiproperty"
local uiutils       = require "widget.utils"
local hierarchy     = require "hierarchy_edit"
local math3d        = require "math3d"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"

local serialize     = import_package "ant.serialize"

local gizmo         = ecs.require "gizmo.gizmo"

local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local icamera       = ecs.import.interface "ant.camera|icamera"
local irq           = ecs.import.interface "ant.render|irenderqueue"

local cameraview = {}

local function camera_template(eid)
    local p = hierarchy:get_template(eid)
    return p.template.data
end

local function create_transform_property(cv)
    return uiproperty.Group({label="Transform", flags = imgui.flags.TreeNode{"DefaultOpen"} }, {
        uiproperty.Float({label="Scale", speed=0.01, dim=3, disable=true}, {
            getter = function ()
                return math3d.tovalue(iom.get_scale(world:entity(cv.eid)))
            end,
            setter = function (value)
                iom.set_scale(world:entity(cv.eid), value)
                local ct = camera_template(cv.eid)
                local s = ct.scene.srt.s
                if s == nil then
                    s = {}
                    ct.scene.srt.s = s
                end
                s[1], s[2], s[3] = value[1], value[2], value[3]
            end
        }),
        uiproperty.Float({label="Rotation", speed=0.01, dim=3},{
            getter = function ()
                local v = math3d.tovalue(math3d.quat2euler(iom.get_rotation(world:entity(cv.eid))))
                v[1], v[2], v[3] = math.deg(v[1]), math.deg(v[2]), math.deg(v[3])
                return v
            end,
            setter = function (value)
                local q = math3d.quaternion{math.rad(value[1]), math.rad(value[2]), math.rad(value[3])}
                iom.set_rotation(world:entity(cv.eid), q)
                local ct = camera_template(cv.eid)
                local r = ct.scene.srt.r
                if r == nil then
                    r = {}
                    ct.scene.srt.r = r
                end
                local qq = math3d.tovalue(q)
                r[1], r[2], r[3], r[4] = qq[1], qq[2], qq[3], qq[4]
            end
        }),
        uiproperty.Float({label="Translation", speed=0.01, dim=3},{
            getter = function ()
                return math3d.tovalue(iom.get_position(world:entity(cv.eid)))
            end,
            setter = function (value)
                iom.set_position(world:entity(cv.eid), value)
                local ct = camera_template(cv.eid)
                local t = ct.scene.srt.t
                if t == nil then
                    t = {}
                    ct.scene.srt.t = t
                end
                t[1], t[2], t[3] = value[1], value[2], value[3]
            end
        })
    })

end

local function create_frustum_property(cv)
    local fov = uiproperty.Float({label="Fov", speed=0.01, min=0.1, max=180},{
        getter = function ()
            local f = icamera.get_frustum(cv.eid)
            return f.fov
        end,
        setter = function (value)
            icamera.set_frustum_fov(world:entity(cv.eid), value)
            local ct = camera_template(cv.eid)
            ct.camera.frustum.fov = value
        end,
    })

    function fov:is_visible()
        local f = icamera.get_frustum(cv.eid)
        return ((not f.ortho) and f.fov) and self.visible or false
    end

    local aspect = uiproperty.Float({label="Aspect", speed=0.01, min=0.00001}, {
        getter = function ()
            local f = icamera.get_frustum(cv.eid)
            return f.aspect
        end,
        setter = function (value)
            icamera.set_frustum_aspect(world:entity(cv.eid), value)
            local ct = camera_template(cv.eid)
            ct.camera.frustum.aspect = value
        end,
    })
    function aspect:is_visible()
        local f = icamera.get_frustum(cv.eid)
        return ((not f.ortho) and f.aspect) and self.visible or false
    end

    local function set_frustum_item(eid, n, value)
        local f = icamera.get_frustum(cv.eid)
        local ff = {}
        for k, v in pairs(f) do ff[k] = v end
        ff[n] = value
        icamera.set_frustum(world:entity(eid), ff)
        camera_template(eid).camera.frustum[n] = value
    end

    local left = uiproperty.Float({label="Left", speed=0.1}, {
        getter = function ()
            local f = icamera.get_frustum(cv.eid)
            return f.l
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 'l', value)
        end
    })
    function left:is_visible()
        local f = icamera.get_frustum(cv.eid)
        return f.l and self.visible or false
    end

    local right = uiproperty.Float({label="Right", speed=0.1}, {
        getter = function ()
            local f = icamera.get_frustum(cv.eid)
            return f.r
        end,
        setter = function (value)
            set_frustum_item(cv.eid, "r", value)
        end
    })

    function right:is_visible()
        local f = icamera.get_frustum(cv.eid)
        return f.r and self.visible or false
    end

    local top = uiproperty.Float({label="Top", speed=0.1}, {
        getter = function ()
            return icamera.get_frustum(cv.eid).t
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 't', value)
        end
    })

    function top:is_visible()
        return icamera.get_frustum(cv.eid).t and self.visible or false
    end

    local bottom = uiproperty.Float({label="Bottom", speed=0.1}, {
        getter = function ()
            return icamera.get_frustum(cv.eid).b
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 'b', value)
        end
    })
    function bottom:is_visible()
        return icamera.get_frustum(cv.eid).b and self.visible or false
    end

    return uiproperty.Group({label="Frustum", flags=0},{
        uiproperty.Bool({label="Ortho"}, {
            getter = function ()
                return icamera.get_frustum(cv.eid).ortho ~= nil
            end,
            setter = function (value)
                set_frustum_item(cv.eid, 'ortho', value)
                fov:set_visible(not value)
                aspect:set_visible(not value)
            end,
        }),
        fov, aspect,
        left, right, top, bottom,
        uiproperty.Float({label="Near", speed=0.1, min=0.01}, {
            getter = function ()
                local f = icamera.get_frustum(cv.eid)
                return f.n
            end,
            setter = function (value)
                icamera.set_frustum_near(cv.eid, value)
                local ct = camera_template(cv.eid)
                ct.camera.frustum.n = value
            end
        }),
        uiproperty.Float({label="Far", speed=0.1, min=0.01}, {
            getter = function ()
                local f = icamera.get_frustum(cv.eid)
                return f.f
            end,
            setter = function (value)
                icamera.set_frustum_far(cv.eid, value)
                camera_template(cv.eid).camera.frustum.f = value
            end
        })
    })
end

local function camera_exposure(eid)
    return world:entity(eid).exposure
end

local EXPOSURE_TYPE_options<const> = {"Manual", "Auto"}
local APERTURE_SIZE_options<const> = {
    "1.8" , "2.0" , "2.2" , "2.5" , "2.8" , "3.2" , "3.5" , "4.0" , "4.5" , "5.0" , "5.6" ,
    "6.3" , "7.1" , "8.0" , "9.0" , "10.0", "11.0", "13.0", "14.0", "16.0", "18.0", "20.0",
    "22.0",
}

local ISO_options<const> = {
    "ISO100",
    "ISO200",
    "ISO400",
    "ISO800",
}

local SHUTTER_SPEED_options<const> = {
    "1/1"  ,
    "1/2"  ,
    "1/4"  ,
    "1/8"  ,
    "1/15" ,
    "1/30" ,
    "1/60" ,
    "1/125",
    "1/250",
    "1/500",
    "1/1000",
    "1/2000",
    "1/4000",
}

local DEFAULT_EXPOSURE<const> = {
    type 			= "manual",
    aperture 		= 16.0,
    shutter_speed 	= 0.008,
    ISO 			= 100,
}

local function deep_copy(t)
    local tt = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            tt[k] = deep_copy(v)
        else
            tt[k] = v
        end
    end
    return tt
end

local function find_exposure_policy(policies)
    for idx, pp in ipairs(policies) do
        if pp:match "exposure" then
            return idx
        end
    end
end

local function create_exposure_property(cv)
    local function gen_modifier(n)
        return {
            getter = function ()
                local ee = camera_exposure(cv.eid) or DEFAULT_EXPOSURE
                return ee[n]
            end,
            setter = function (value)
                camera_exposure(cv.eid)[n] = value
                camera_template(cv.eid)[n] = value
            end
        }
    end
    local exposure = uiproperty.Group({label="Exposure", flags=0},{
        uiproperty.Combo({label="Type",     options =   EXPOSURE_TYPE_options}, gen_modifier "type"),
        uiproperty.Combo({label="Aperture", options =   APERTURE_SIZE_options}, gen_modifier "aperture"),
        uiproperty.Combo({label="Shutter speed", options=SHUTTER_SPEED_options},gen_modifier "shutter_speed"),
        uiproperty.Combo({label="ISO",      options=ISO_options},               gen_modifier "ISO"),
    })

    function exposure:is_disable()
        return camera_exposure(cv.eid) == nil and true or self.disable
    end

    return uiproperty.SameLineContainer({}, {
        uiproperty.Bool({label=""}, {
            getter = function ()
                return camera_exposure(cv.eid) ~= nil
            end,
            setter = function (value)
                local e = world:entity(cv.eid)
                local template = hierarchy:get_template(cv.eid).template

                local p_idx = find_exposure_policy(template.policy)
                assert((e.exposure and p_idx) or (e.exposure == nil and (not p_idx)))
                if value then
                    template.policy[#template.policy+1] = "ant.camera|exposure"
                    if template.data.exposure == nil then
                        template.data.exposure = DEFAULT_EXPOSURE
                    end
                else
                    if p_idx then
                        table.remove(template.policy, p_idx)
                    end
                    template.data.exposure = nil
                end

                local t = deep_copy(template)
                t.on_ready = function (ee)
                    w:sync("id:in", ee)
                    for q in w:select "queue_name:in camera_ref:in" do
                        if cv.eid == q.camera_ref then
                            irq.set_camera(q.queue_name, ee.id)
                        end
                    end
                    cv.eid = ee.id
                end
            end
        }),
        exposure
    })

end

local function create_serialize_ui(cv)
    local function save_prefab(path, p)
        local c = serialize.stringify{p}
        local f<close> = lfs.open(lfs.path(path), "w")
        f:write(c)
    end
    local save = uiproperty.Button({label="Save"},{
        click = function ()
            local p = hierarchy:get_template(cv.eid)
            save_prefab(p.filename, p.template)
        end
    })
    function save:is_disable()
        local p = hierarchy:get_template(cv.eid)
        if p.filename == nil then
            return true
        end
        return self.disable
    end

    return uiproperty.SameLineContainer({},{
        save,
        uiproperty.Button({label="Save As"},{
            click = function ()
                local path = uiutils.get_saveas_path("Prefab", "prefab")
                local p = hierarchy:get_template(cv.eid)
                save_prefab(path, p.template)
                p.filename = path

            end
        }),
    })
end

function cameraview:init()
    self.transform = create_transform_property(self)
    self.frustum = create_frustum_property(self)

    self.exposure = create_exposure_property(self)

    self.serialize = create_serialize_ui(self)
end

function cameraview:update()
    self.transform:update()
    self.frustum:update()
    self.exposure:update()
    self.serialize:update()
end

function cameraview:set_model(eid)
    self.eid = eid
    self:update()
end

function cameraview:show()
    self:update()
    self.transform:show()
    self.frustum:show()
    self.exposure:show()
    self.serialize:show()
end

return cameraview