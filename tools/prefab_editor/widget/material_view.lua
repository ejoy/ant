local ecs = ...
local world = ecs.world
local w = world.w

local imaterial   = ecs.import.interface "ant.asset|imaterial"
local ies         = ecs.import.interface "ant.scene|ientity_state"
local irender     = ecs.import.interface "ant.render|irender"

local prefab_mgr  = ecs.require "prefab_manager"
ecs.require "widget.base_view"

local assetmgr  = import_package "ant.asset"
local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local stringify = import_package "ant.serialize".stringify
local utils     = require "common.utils"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy_edit"

local uiproperty= require "widget.uiproperty"
local view_class= require "widget.view_class"

local BaseView, MaterialView = view_class.BaseView, view_class.MaterialView

local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local vfs       = require "vfs"
local access    = require "vfs.repoaccess"
local imgui     = require "imgui"
local datalist  = require "datalist"
local math3d    = require "math3d"
local bgfx      = require "bgfx"

local default_setting = datalist.parse(fs.open "/pkg/ant.resources/settings/default.setting":read "a")

local function material_template(eid)
    local prefab = hierarchy:get_template(eid)
    return prefab.template.data.material
end

local function reload(eid, mtl)
    local prefab = hierarchy:get_template(eid)
    prefab.template.data.material = mtl
    prefab_mgr:save_prefab()
    prefab_mgr:reload()
end

local ON_OFF_options<const> = {
    "on", "off"
}

local DEPTH_TYPE_options<const> = {
    "inv_z", "linear"
}

local function build_fx_ui(mv)
    local function shader_file_ui(st)
        return uiproperty.ResourcePath({label = "VS", extension = ".sc", readonly = true}, {
            getter = function()
                return material_template(mv.eid).fx[st]
            end,
            setter = function(value)
                material_template(mv.eid).fx[st] = value
                mv.need_reload = true
            end,
        })
    end

    local function setting_filed(which)
        local s = material_template(mv.eid).fx.setting
        return s[which] or default_setting[which]
    end

    return uiproperty.Group({label="FX"}, {
        vs = shader_file_ui "vs",
        fs = shader_file_ui "fs",
        cs = shader_file_ui "cs",
        setting         = uiproperty.Group({label="Setting"},{
            lighting = uiproperty.Bool({label="Lighting"}, {
                getter = function() return setting_filed "lighting" == "on" end,
                setter = function (value)
                    local s = material_template(mv.eid).fx.setting
                    s.lighting = value and "on" or "off"
                end
            }),
            layer    = uiproperty.Combo({label = "Layer", options = irender.layer_names()},{
                getter = function() return setting_filed "surfacetype" end,
                setter = function(value)
                    local s = material_template(mv.eid).fx.setting
                    s.surfacetype = value
                    mv.need_reload = true
                end,
            }),
            shadow_cast = uiproperty.Bool({label = "ShadowCast"}, {
                getter = function() return ies.has_state(mv.eid, "cast_shadow") end,
                setter = function(value)
                    local prefab = hierarchy:get_template(mv.eid)
                    local state = prefab.data.state
                    --TODO: need remove not string entity state
                    if type(state) == "string" then
                        if not state:match "cast_shadow" then
                            prefab.data.state = state .. "|cast_shadow"
                        end
                    else
                        local m = ies.filter_mask(mv.eid)
                        prefab.data.state = value and (state|m) or (state&(~m))
                    end
                    mv.need_reload = true
                end,
            }),
            shadow_receive = uiproperty.Bool({label = "ShadowReceive"}, {
                getter = function () return setting_filed "shadow_receive" == "on" end,
                setter = function(value)
                    local s = material_template(mv.eid).fx.setting
                    s.shadow_receive = value and "on" or "off"
                    mv.need_reload = true
                end,
            }),
            depth_type = uiproperty.Combo({label = "DepthType", options = DEPTH_TYPE_options}, {
                getter = function () return setting_filed "depth_type" end,
                setter = function(value)
                    local s = material_template(mv.eid).fx.setting
                    s.depth_type = value
                    mv.need_reload = true
                end,
            })
        })
    })

end

--TODO: hard code here, just check pbr material for show pbr ui
--should add info in material file to let the ui system know how to show
local function is_pbr_material(t)
    local fx = t.fx
    return fx.vs:match "vs_pbr" and fx.fs:match "fs_pbr"
end

local function which_property_type(p)
    if p.texture then
        return "texture"
    end

    local n = #p
    if n > 0 then
        local et = type(p[1])
        if et == "number" then
            return n == 4 and "v4" or "m4"
        end

        return "v4_array"
    end
end

local function create_property_ui(n, p, mv)
    local tt = which_property_type(p)
    if tt == "texture" then
        -- should add ui to extent texutre
        return uiproperty.EditText({label = n}, {
            getter = function ()
                local t = material_template(mv.eid)
                return t.properties[n].texture
            end,
            setter = function (value)
                local t = material_template(mv.eid)
                t.properties[n].texture = value
                mv.need_reload = true
            end,
        })
    elseif tt == "v4" or tt == "m4" then
        return uiproperty.Float({label=n}, {
            getter = function()
                local t = material_template(mv.eid)
                return t.properties[n]
            end,
            setter = function(value)
                local t = material_template(mv.eid)
                local pp = t.properties[n]
                for i=1, #value do
                    pp[i] = value[i]
                end
                mv.need_reload = true
            end
        })
    elseif tt == "v4_array" then
        local pp = {}
        for i=1, #p do
            pp[i] = uiproperty.Float({label=tostring(i)}, {
                getter = function ()
                    local t = material_template(mv.eid)
                    return t.properties[n][i]
                end,
                setter = function (value)
                    local t = material_template(mv.eid)
                    local ppp = t.properties[n][i]
                    for ii=1, #value do
                        ppp[ii] = value[ii]
                    end
                    mv.need_reload = true
                end
            })
        end
        return uiproperty.Group({label=n}, pp)
    else
        error(("property:%s, not support uniform type:%s"):format(n, tt))
    end
end

local function build_properties_ui(mv)
    local t = material_template(assert(mv.eid))
    local properties = {}
    if false then--is_pbr_material(t) then
    else
        if t.properties then
            for n, p in pairs(t.properties) do
                properties[n] = create_property_ui(p)
            end
        end
    end
    return uiproperty.Group({label="Properties",}, properties)
end

local PT_options<const> = {
    "Points",
    "Lines",
    "LineStrip",
    "Triangles",
    "TriangleStrip",
}

local BLEND_options<const> = {
    "ADD",
    "ALPHA",
    "DARKEN",
    "LIGHTEN",
    "MULTIPLY",
    "NORMAL",
    "SCREEN",
    "LINEAR_BURN",
}

local BLEND_FUNC_options<const> = {
    "ZERO",
    "ONE",
    "SRC_COLOR",
    "INV_SRC_COLOR",
    "SRC_ALPHA",
    "INV_SRC_ALPHA",
    "DST_ALPHA",
    "INV_DST_ALPHA",
    "DST_COLOR",
    "INV_DST_COLOR",
    "SRC_ALPHA_SAT",
    "FACTOR",
    "INV_FACTOR",
}

local BLEND_FUNC_mapper = {}
local BLEND_FUNC_remapper = {}
for idx, v in ipairs{
    '0',
    '1',
    's',
    'S',
    'a',
    'A',
    'b',
    'B',
    'd',
    'D',
    't',
    'f',
    'F',
} do
    local k = BLEND_FUNC_options[idx]
    BLEND_FUNC_mapper[v] = k
    BLEND_FUNC_remapper[k] = v
end

local BLEND_EQUATION_options<const> = {
    "ADD",
    "SUB",
    "REV",
    "MIN",
    "MAX",
}

local DEPTH_TEST_options<const> = {
    "NEVER",
    "ALWAYS",
    "LEQUAL",
    "EQUAL",
    "GEQUAL",
    "GREATER",
    "NOTEQUAL",
    "LESS",
    "NONE",
}

local CULL_options<const> = {
    "CCW",
    "CW",
    "NONE",
}

local function create_simple_state_ui(t, en, ln, mv)
    return uiproperty[t]({lable=ln},{
        getter = function ()
            local mt = material_template(mv.eid)
            return mt.state[en]
        end,
        setter = function (value)
            local mt = material_template(mv.eid)
            mt.state[en] = value
            mv.need_reload = true
        end,
    })
end

local function create_write_mask_ui(en, mv)
    uiproperty.Bool({label=en}, {
        getter = function ()
            local t = material_template(mv.eid)
            return t.state.WRITE_MASK:match(en)
        end,
        setter = function (value)
            local t = material_template(mv.eid)
            if value then
                if not t.state.WRITE_MASK:match(en) then
                    t.state.WRITE_MASK = en .. t.state.WRITE_MASK
                end
            else
                t.state.WRITE_MASK = t.state.WRITE_MASK:gsub(en, "")
            end
            mv.need_reload = true
        end
    })
end

local function build_state_ui(mv)
    return uiproperty.Group{{label="State", options = PT_options},{
        PT = uiproperty.Combo({label = "Pritmive Type", }, {
            getter = function ()
                local t = material_template(mv.eid)
                if t.state.PT == nil then
                    return "Triangles"
                end

                return t.state.PT
            end,
            setter = function(value)
                local t = material_template(mv.eid)
                if value == "Triangles" then
                    t.state.PT = nil
                end
                t.state.PT = value
                mv.need_reload = true
            end
        }),

        BLEND = uiproperty.Group({label="Blend Setting",}, {
            TYPE = create_simple_state_ui("Combo", {label="Type", options=BLEND_options}, "BLEND", mv),
            ENABLE = create_simple_state_ui("Bool", {label="Enable"}, "BLEND_ENABLE", mv),
            EQUATION = create_simple_state_ui("Combo", {label="Equation", options=BLEND_EQUATION_options}, "BLEND_EQUATION", mv),
            FUNC = uiproperty.Group({label="Function"}, {
                USE_ALPHA_OP = uiproperty.Bool({label="Use Separate Alpha"},{
                    getter = function ()
                        return mv.blend_use_alpha
                    end,
                    setter = function (value)
                        mv.blend_use_alpha = value
                    end,
                }),
                SRC_RGB = uiproperty.Combo({label="RGB Source", options=BLEND_FUNC_options}, {
                    getter = function ()
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local k = f:sub(1, 1)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local d = f:sub(2, 2)
                        t.state.BLEND_FUNC = BLEND_FUNC_remapper[value] .. d
                        mv.need_reload = true
                    end,
                }),
                DST_RGB = uiproperty.Combo({label="RGB Destination", options=BLEND_FUNC_options},{
                    getter = function ()
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local k = f:sub(2, 2)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local s = f:sub(1, 1)
                        t.state.BLEND_FUNC = s .. BLEND_FUNC_remapper[value]
                        mv.need_reload = true
                    end,
                }),
                SRC_ALPHA = uiproperty.Combo({label="Alpha Source", options=BLEND_FUNC_options, disable=true}, {
                    getter = function ()
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        local d = f:sub(4, 4)
                        t.state.BLEND_FUNC = BLEND_FUNC_remapper[value] .. d
                        mv.need_reload = true
                    end,
                }),
                DST_ALPHA = uiproperty.Combo({label="Alpha Destination", options=BLEND_FUNC_options, disable=true},{
                    getter = function ()
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if #f ~= 4 then
                            return "NONE"
                        end
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if #f == 4 then
                            local s = f:sub(4, 4)
                            t.state.BLEND_FUNC = s .. BLEND_FUNC_remapper[value]
                            mv.need_reload = true
                        end
                    end,
                }),
            })
        }),
        ALPHA_REF   = create_simple_state_ui("Float", {label ="Alpha Reference"}, "ALPHA_REF", mv),
        POINT_SIZE  = create_simple_state_ui("Float", {label = "Point Size"}, "POINT_SIZE", mv),
        MSAA        = create_simple_state_ui("Bool", {label="MSAA"}, "MSAA", mv),
        LINEAA      = create_simple_state_ui("Bool", {label="LINE AA"}, "LINEAA", mv),
        CONSERVATIVE_RASTER = create_simple_state_ui("Bool", "CONSERVATIVE_RASTER", mv),
        FRONT_CCW   = create_simple_state_ui("Bool", "FRONT_CCW", mv),
        WRITE_MASK = uiproperty.Group({label="Write Mask"},{
            R = create_write_mask_ui("R", mv),
            G = create_write_mask_ui("G", mv),
            B = create_write_mask_ui("B", mv),
            A = create_write_mask_ui("A", mv),
            Z = create_write_mask_ui("Z", mv),
        }),
        DEPTH_TEST = create_simple_state_ui("Combo", {label="Depth Test", options=DEPTH_TEST_options}, "DEPTH_TEST", mv),
        CULL = create_simple_state_ui("Combo", {label="Cull Type", options=CULL_options}, "CULL", mv),
    }}
end

function MaterialView:_init()
    BaseView._init(self)
    self.mat_file       = uiproperty.ResourcePath({label = "File", extension = ".material"},{
        getter = function() return self.mat_file:get_path() end,
        setter = function (value)
            prefab_mgr:update_material(self.eid, value)
            self:set_model(nil)
        end,
    })

    self.fx         = build_fx_ui(self)
    self.state      = build_state_ui(self)
    self.save       = uiproperty.Button({label="Save"}, {
        click = function ()
        end,
    })
    self.saveas     = uiproperty.Button({label="Save As ..."}, {
        click = function ()
        end
    })
end
-- local global_data = require "common.global_data"
-- function MaterialView:on_saveas_mat()
--     local path = uiutils.get_saveas_path("Material", "material")
--     if path then
--         do_save(self.eid, path)
--         local vpath = "/" .. tostring(access.virtualpath(global_data.repo, fs.path(path)))
--         if vpath == self.mat_file:get_path() then
--             assetmgr.unload(vpath)
--         end
--     end
-- end

-- function MaterialView:on_set_mat(value)
--     prefab_mgr:update_material(self.eid, value)
--     self:set_model(nil)
-- end

local function is_readonly_resource(p)
    return p:match "|"
end

function MaterialView:set_model(eid)
    if not BaseView.set_model(self, eid) then 
        return false
    end
    --update ui state
    local e = world[eid]
    self.mat_file.disable = is_readonly_resource(tostring(e.material))
    self.properties = build_properties_ui(self)

    return true
end

function MaterialView:update()
    if self.eid then
        self.fx:update()
        self.properties:update()
        self.state:update()
        --self.stencil:show()

        if self.need_reload then
            local p = self.mat_file:get_path()
            reload(self.eid, p)
        end
    end
end

function MaterialView:show()
    if self.eid then
        BaseView.show(self)
        self.fx:show()
        self.properties:show()
        self.state:show()
        --self.stencil:show()
    end

end

return MaterialView