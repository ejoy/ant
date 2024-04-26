local ecs   = ...
local world = ecs.world
local w     = world.w

local serialize     = import_package "ant.serialize"
local hierarchy     = ecs.require "hierarchy_edit"
local iom           = ecs.require "ant.objcontroller|obj_motion"
local icamera       = ecs.require "ant.camera|camera"
local irq           = ecs.require "ant.render|renderqueue"
local math3d        = require "math3d"
local ImGui         = require "imgui"
local uiproperty    = require "widget.uiproperty"
local uiutils       = require "widget.utils"

local CameraView = {}

local function camera_template(eid)
    local p = hierarchy:get_node_info(eid)
    return p.template.data
end

local function create_transform_property(cv)
    return uiproperty.Group({label="Transform", flags = ImGui.TreeNodeFlags {"DefaultOpen"} }, {
        uiproperty.Float({label="Scale", speed=0.01, dim=3, disable=true}, {
            getter = function ()
                local cve <close> = world:entity(cv.eid)
                return math3d.tovalue(iom.get_scale(cve))
            end,
            setter = function (value)
                local cve <close> = world:entity(cv.eid)
                iom.set_scale(cve, value)
                local ct = camera_template(cv.eid)
                local s = ct.scene.s
                if s == nil then
                    s = {}
                    ct.scene.s = s
                end
                s[1], s[2], s[3] = value[1], value[2], value[3]
            end
        }),
        uiproperty.Float({label="Rotation", speed=0.01, dim=3},{
            getter = function ()
                local cve <close> = world:entity(cv.eid)
                local v = math3d.tovalue(math3d.quat2euler(iom.get_rotation(cve)))
                v[1], v[2], v[3] = math.deg(v[1]), math.deg(v[2]), math.deg(v[3])
                return v
            end,
            setter = function (value)
                local q = math3d.quaternion{math.rad(value[1]), math.rad(value[2]), math.rad(value[3])}
                local cve <close> = world:entity(cv.eid)
                iom.set_rotation(cve, q)
                local ct = camera_template(cv.eid)
                local r = ct.scene.r
                if r == nil then
                    r = {}
                    ct.scene.r = r
                end
                local qq = math3d.tovalue(q)
                r[1], r[2], r[3], r[4] = qq[1], qq[2], qq[3], qq[4]
            end
        }),
        uiproperty.Float({label="Translation", speed=0.01, dim=3},{
            getter = function ()
                local cve <close> = world:entity(cv.eid)
                return math3d.tovalue(iom.get_position(cve))
            end,
            setter = function (value)
                local cve <close> = world:entity(cv.eid)
                iom.set_position(cve, value)
                local ct = camera_template(cv.eid)
                local t = ct.scene.t
                if t == nil then
                    t = {}
                    ct.scene.t = t
                end
                t[1], t[2], t[3] = value[1], value[2], value[3]
            end
        })
    })

end

local function create_frustum_property(cv)
    local fov = uiproperty.Float({label="Fov", speed=0.01, min=0.1, max=180},{
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            local f = icamera.get_frustum(cve)
            return f.fov
        end,
        setter = function (value)
            local cve <close> = world:entity(cv.eid)
            icamera.set_frustum_fov(cve, value)
            local ct = camera_template(cv.eid)
            ct.camera.frustum.fov = value
        end,
    })

    function fov:is_visible()
        local cve <close> = world:entity(cv.eid)
        local f = icamera.get_frustum(cve)
        return ((not f.ortho) and f.fov) and self.visible or false
    end

    local aspect = uiproperty.Float({label="Aspect", speed=0.01, min=0.00001}, {
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            local f = icamera.get_frustum(cve)
            return f.aspect
        end,
        setter = function (value)
            local cve <close> = world:entity(cv.eid)
            icamera.set_frustum_aspect(cve, value)
            local ct = camera_template(cv.eid)
            ct.camera.frustum.aspect = value
        end,
    })
    function aspect:is_visible()
        local cve <close> = world:entity(cv.eid)
        local f = icamera.get_frustum(cve)
        return ((not f.ortho) and f.aspect) and self.visible or false
    end

    local function set_frustum_item(eid, n, value)
        local cve <close> = world:entity(cv.eid)
        local f = icamera.get_frustum(cve)
        local ff = {}
        for k, v in pairs(f) do ff[k] = v end
        ff[n] = value
        local e <close> = world:entity(eid)
        icamera.set_frustum(e, ff)
        camera_template(eid).camera.frustum[n] = value
    end

    local left = uiproperty.Float({label="Left", speed=0.1}, {
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            local f = icamera.get_frustum(cve)
            return f.l
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 'l', value)
        end
    })
    function left:is_visible()
        local cve <close> = world:entity(cv.eid)
        local f = icamera.get_frustum(cve)
        return f.l and self.visible or false
    end

    local right = uiproperty.Float({label="Right", speed=0.1}, {
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            local f = icamera.get_frustum(cve)
            return f.r
        end,
        setter = function (value)
            set_frustum_item(cv.eid, "r", value)
        end
    })

    function right:is_visible()
        local cve <close> = world:entity(cv.eid)
        local f = icamera.get_frustum(cve)
        return f.r and self.visible or false
    end

    local top = uiproperty.Float({label="Top", speed=0.1}, {
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            return icamera.get_frustum(cve).t
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 't', value)
        end
    })

    function top:is_visible()
        local cve <close> = world:entity(cv.eid)
        return icamera.get_frustum(cve).t and self.visible or false
    end

    local bottom = uiproperty.Float({label="Bottom", speed=0.1}, {
        getter = function ()
            local cve <close> = world:entity(cv.eid)
            return icamera.get_frustum(cve).b
        end,
        setter = function (value)
            set_frustum_item(cv.eid, 'b', value)
        end
    })
    function bottom:is_visible()
        local cve <close> = world:entity(cv.eid)
        return icamera.get_frustum(cve).b and self.visible or false
    end

    return uiproperty.Group({label="Frustum", flags=0},{
        uiproperty.Bool({label="Ortho"}, {
            getter = function ()
                local cve <close> = world:entity(cv.eid)
                return icamera.get_frustum(cve).ortho
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
                local cve <close> = world:entity(cv.eid)
                local f = icamera.get_frustum(cve)
                return f.n
            end,
            setter = function (value)
                local cve <close> = world:entity(cv.eid)
                icamera.set_frustum_near(cve, value)
                local ct = camera_template(cv.eid)
                ct.camera.frustum.n = value
            end
        }),
        uiproperty.Float({label="Far", speed=0.1, min=0.01}, {
            getter = function ()
                local cve <close> = world:entity(cv.eid)
                local f = icamera.get_frustum(cve)
                return f.f
            end,
            setter = function (value)
                local cve <close> = world:entity(cv.eid)
                icamera.set_frustum_far(cve, value)
                camera_template(cv.eid).camera.frustum.f = value
            end
        })
    })
end

local function camera_exposure(eid)
    local e <close> = world:entity(eid, "exposure?in")
    return e.exposure
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
        uiproperty.Bool({label="##"}, {
            getter = function ()
                return camera_exposure(cv.eid) ~= nil
            end,
            setter = function (value)
                local e <close> = world:entity(cv.eid, "exposure?in")
                local template = hierarchy:get_node_info(cv.eid).template

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
                    w:extend(ee, "eid:in")
                    for q in w:select "queue_name:in camera_ref:in" do
                        if cv.eid == q.camera_ref then
                            irq.set_camera_from_queuename(q.queue_name, ee.eid)
                        end
                    end
                    cv.eid = ee.eid
                end
            end
        }),
        exposure
    })

end

local function create_serialize_ui(cv)
    local function save_prefab(path, p)
        local c = serialize.stringify{p}
        local f <close> = assert(io.open(path, "w"))
        f:write(c)
    end
    local save = uiproperty.Button({label="Save"},{
        click = function ()
            local p = hierarchy:get_node_info(cv.eid)
            save_prefab(p.filename, p.template)
        end
    })
    function save:is_disable()
        local p = hierarchy:get_node_info(cv.eid)
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
                local p = hierarchy:get_node_info(cv.eid)
                save_prefab(path, p.template)
                p.filename = path

            end
        }),
    })
end

function CameraView:_init()
    if self.inited then
        return
    end
    self.inited = true

    -- self.transform = create_transform_property(self)
    self.copy_maincamera = uiproperty.Button({label="SRT From MainCamera"})
    self.copy_maincamera:set_click(function() world:pub {"CopyMainCamera"} end)
    self.frustum = create_frustum_property(self)
    self.exposure = create_exposure_property(self)
    self.serialize = create_serialize_ui(self)
end

function CameraView:update()
    if not self.eid then
        return
    end
    -- self.transform:update()
    self.frustum:update()
    self.exposure:update()
    self.serialize:update()
end

function CameraView:set_eid(eid, base_panel)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "camera?in")
    if not e.camera then
        self.eid = nil
        return
    end
    self.eid = eid
    self:update()
    base_panel:disable_scale()
end

function CameraView:show()
    if not self.eid then
        return
    end
    -- self.transform:show()
    self.copy_maincamera:show()
    self.frustum:show()
    self.exposure:show()
    self.serialize:show()
end

return function ()
    CameraView:_init()
    return CameraView
end