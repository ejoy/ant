local ecs   = ...
local world = ecs.world
local w     = world.w

local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local math3d        = require "math3d"

local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local icamera       = ecs.import.interface "ant.camera|icamera"

local cameraview = {}

local function camera_template(e)
    local p = hierarchy:get_template(e)
    return p.template.data
end

local function create_transform_property(cv)
    return uiproperty.Group({label="Transform", flags = 0}, {
        uiproperty.Float({label="Scale", speed=0.01, dim=3, disable=true}, {
            getter = function ()
                return math3d.tovalue(iom.get_scale(cv.e))
            end,
            setter = function (value)
                iom.set_scale(cv.e, value)
                local ct = camera_template(cv.e)
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
                local v = math3d.tovalue(math3d.quat2euler(iom.get_rotation(cv.e)))
                v[1], v[2], v[3] = math.deg(v[1]), math.deg(v[2]), math.deg(v[3])
                return v
            end,
            setter = function (value)
                local q = math3d.quaternion{math.rad(value[1]), math.rad(value[2]), math.rad(value[3])}
                iom.set_rotation(cv.e, q)
                local ct = camera_template(cv.e)
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
                return math3d.tovalue(iom.get_position(cv.e))
            end,
            setter = function (value)
                iom.set_position(cv.e, value)
                local ct = camera_template(cv.e)
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
            local f = icamera.get_frustum(cv.e)
            return f.fov
        end,
        setter = function (value)
            icamera.set_frustum_fov(cv.e, value)
            local ct = camera_template(cv.e)
            ct.camera.frustum.fov = value
        end,
    })

    function fov:is_visible()
        local f = icamera.get_frustum(cv.e)
        return ((not f.ortho) and f.fov) and self.visible or false
    end

    local aspect = uiproperty.Float({label="Aspect", speed=0.01, min=0.00001}, {
        getter = function ()
            local f = icamera.get_frustum(cv.e)
            return f.aspect
        end,
        setter = function (value)
            icamera.set_frustum_aspect(cv.e, value)
            local ct = camera_template(cv.e)
            ct.camera.frustum.aspect = value
        end,
    })
    function aspect:is_visible()
        local f = icamera.get_frustum(cv.e)
        return ((not f.ortho) and f.aspect) and self.visible or false
    end

    local function set_frustum_item(e, n, value)
        local f = icamera.get_frustum(cv.e)
        local ff = {}
        for k, v in pairs(f) do ff[k] = v end
        ff[n] = value
        icamera.set_frustum(e, ff)
        camera_template(e).camera.frustum[n] = value
    end

    local left = uiproperty.Float({label="Left", speed=0.01}, {
        getter = function ()
            local f = icamera.get_frustum(cv.e)
            return f.l
        end,
        setter = function (value)
            set_frustum_item(cv.e, 'l', value)
        end
    })
    function left:is_visible()
        local f = icamera.get_frustum(cv.e)
        return f.l and self.visible or false
    end

    local right = uiproperty.Float({label="Right", speed=0.01}, {
        getter = function ()
            local f = icamera.get_frustum(cv.e)
            return f.r
        end,
        setter = function (value)
            set_frustum_item(cv.e, "r", value)
        end
    })

    function right:is_visible()
        local f = icamera.get_frustum(cv.e)
        return f.r and self.visible or false
    end

    local top = uiproperty.Float({label="Top", speed=0.01}, {
        getter = function ()
            return icamera.get_frustum(cv.e).t
        end,
        setter = function (value)
            set_frustum_item(cv.e, 't', value)
        end
    })

    function top:is_visible()
        return icamera.get_frustum(cv.e).t and self.visible or false
    end

    local bottom = uiproperty.Float({label="Bottom", speed=0.01}, {
        getter = function ()
            return icamera.get_frustum(cv.e).b
        end,
        setter = function (value)
            set_frustum_item(cv.e, 'b', value)
        end
    })
    function bottom:is_visible()
        return icamera.get_frustum(cv.e).b and self.visible or false
    end

    return uiproperty.Group({label="Frustum", flags=0},{
        uiproperty.Bool({label="Ortho"}, {
            getter = function ()
                return icamera.get_frustum(cv.e).ortho ~= nil
            end,
            setter = function (value)
                set_frustum_item(cv.e, 'ortho', value)
                fov:set_visible(not value)
                aspect:set_visible(not value)
            end,
        }),
        fov, aspect,
        left, right, top, bottom,
        uiproperty.Float({label="Near", speed=0.01, min=0.01}, {
            getter = function ()
                local f = icamera.get_frustum(cv.e)
                return f.n
            end,
            setter = function (value)
                icamera.set_frustum_near(cv.e, value)
                local ct = camera_template(cv.e)
                ct.frustum.n = value
            end
        }),
        uiproperty.Float({label="Far", speed=0.01, min=0.01}, {
            getter = function ()
                local f = icamera.get_frustum(cv.e)
                return f.f
            end,
            setter = function (value)
                icamera.set_frustum_far(cv.e, value)
                camera_template(cv.e).frustum.f = value
            end
        })
    })
end

function cameraview:init()
    self.transform = create_transform_property(self)
    self.frustum = create_frustum_property(self)
end

function cameraview:update()
    self.transform:update()
    self.frustum:update()
end


function cameraview:set_model(e)
    self.e = e
end

function cameraview:show()
    self.transform:show()
    self.frustum:show()
end

return cameraview