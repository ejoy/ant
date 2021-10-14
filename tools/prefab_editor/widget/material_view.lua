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

local file_cache = {}

local function read_datalist_file(p)
    local c = file_cache[p]
    if c == nil then
        c = datalist.parse(fs.open(fs.path(p)):read "a")
        file_cache[p] = c
    end
    return c
end

local default_setting = read_datalist_file "/pkg/ant.resources/settings/default.setting"

local function material_template(e)
    local prefab = hierarchy:get_template(e)
    local mf = prefab.template.data.material
    return read_datalist_file(mf)
end

local function state_template(e)
    local t = material_template(e)
    if type(t.state) == "string" then
        return read_datalist_file(t.state)
    end
    return t.state
end

local function reload(e, mtl)
    local prefab = hierarchy:get_template(e)
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
        return uiproperty.ResourcePath({label=st, extension = ".sc", readonly = true}, {
            getter = function()
                return material_template(mv.entity).fx[st]
            end,
            setter = function(value)
                material_template(mv.entity).fx[st] = value
                mv.need_reload = true
            end,
        })
    end

    local function setting_filed(which)
        local s = material_template(mv.entity).fx.setting
        s = s or default_setting
        return s[which] or default_setting[which]
    end

    return uiproperty.Group({label="FX"}, {
        shader_file_ui "vs",
        shader_file_ui "fs",
        shader_file_ui "cs",
        uiproperty.Group({label="Setting"},{
            uiproperty.Bool({label="Lighting"}, {
                getter = function() return setting_filed "lighting" == "on" end,
                setter = function (value)
                    local s = material_template(mv.entity).fx.setting
                    s.lighting = value and "on" or "off"
                end
            }),
            uiproperty.Combo({label = "Layer", options = irender.layer_names()},{
                getter = function() return setting_filed "surfacetype" end,
                setter = function(value)
                    local s = material_template(mv.entity).fx.setting
                    s.surfacetype = value
                    mv.need_reload = true
                end,
            }),
            uiproperty.Bool({label = "ShadowCast"}, {
                getter = function() return ies.has_state(mv.entity, "cast_shadow") end,
                setter = function(value)
                    local prefab = hierarchy:get_template(mv.entity)
                    local state = prefab.data.state
                    --TODO: need remove not string entity state
                    if type(state) == "string" then
                        if not state:match "cast_shadow" then
                            prefab.data.state = state .. "|cast_shadow"
                        end
                    else
                        local m = ies.filter_mask(mv.entity)
                        prefab.data.state = value and (state|m) or (state&(~m))
                    end
                    mv.need_reload = true
                end,
            }),
            uiproperty.Bool({label = "ShadowReceive"}, {
                getter = function () return setting_filed "shadow_receive" == "on" end,
                setter = function(value)
                    local s = material_template(mv.entity).fx.setting
                    s.shadow_receive = value and "on" or "off"
                    mv.need_reload = true
                end,
            }),
            uiproperty.Combo({label = "DepthType", options = DEPTH_TYPE_options}, {
                getter = function () return setting_filed "depth_type" end,
                setter = function(value)
                    local s = material_template(mv.entity).fx.setting
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
                local t = material_template(mv.entity)
                return t.properties[n].texture
            end,
            setter = function (value)
                local t = material_template(mv.entity)
                t.properties[n].texture = value
                mv.need_reload = true
            end,
        })
    elseif tt == "v4" or tt == "m4" then
        return uiproperty.Float({label=n}, {
            getter = function()
                local t = material_template(mv.entity)
                return t.properties[n]
            end,
            setter = function(value)
                local t = material_template(mv.entity)
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
                    local t = material_template(mv.entity)
                    return t.properties[n][i]
                end,
                setter = function (value)
                    local t = material_template(mv.entity)
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
    local t = material_template(assert(mv.entity))
    local properties = {}
    if false then--is_pbr_material(t) then
    else
        if t.properties then
            for n, p in pairs(t.properties) do
                properties[#properties+1] = create_property_ui(n, p, mv)
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

local function create_simple_state_ui(t, l, en, mv, def_value)
    return uiproperty[t](l, {
        getter = function ()
            local s = state_template(mv.entity)
            return s[en] or def_value
        end,
        setter = function (value)
            local s = state_template(mv.entity)
            s[en] = value
            mv.need_reload = true
        end,
    })
end

local function create_write_mask_ui(en, mv)
    return uiproperty.Bool({label=en}, {
        getter = function ()
            local s = state_template(mv.entity)
            return s.WRITE_MASK:match(en)
        end,
        setter = function (value)
            local s = state_template(mv.entity)
            if value then
                if not s.WRITE_MASK:match(en) then
                    s.WRITE_MASK = en .. s.WRITE_MASK
                end
            else
                s.WRITE_MASK = s.WRITE_MASK:gsub(en, "")
            end
            mv.need_reload = true
        end
    })
end

local function build_state_ui(mv)
    return uiproperty.Group({label="State"},{
        uiproperty.Combo({label = "Pritmive Type", options=PT_options, id="PT"}, {
            getter = function ()
                local s = state_template(mv.entity)
                return s.PT == nil and "Triangles" or s.PT
            end,
            setter = function(value)
                local s = state_template(mv.entity)
                s.PT = value ~= "Triangles" and value or nil
                mv.need_reload = true
            end
        }),

        uiproperty.Group({label="Blend Setting", id="blend_setting"}, {
            create_simple_state_ui("Combo",{label="Type", options=BLEND_options, id="type"}, "BLEND", mv, BLEND_options[1]),
            create_simple_state_ui("Bool", {label="Enable", id="enable"}, "BLEND_ENABLE", mv),
            create_simple_state_ui("Combo",{label="Equation", id="equation",options=BLEND_EQUATION_options}, "BLEND_EQUATION", mv, BLEND_EQUATION_options[1]),
            uiproperty.Group({label="Function", id="function"}, {
                uiproperty.Bool({label="Use Separate Alpha"},{
                    getter = function ()
                        return mv.blend_use_alpha
                    end,
                    setter = function (value)
                        mv.blend_use_alpha = value
                    end,
                }),
                uiproperty.Combo({label="RGB Source", options=BLEND_FUNC_options, "src_rgb"}, {
                    getter = function ()
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(1, 1)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f then
                            local d = f:sub(2, 2)
                            t.state.BLEND_FUNC = BLEND_FUNC_remapper[value] .. d
                            mv.need_reload = true
                        end
                    end,
                }),
                uiproperty.Combo({label="RGB Destination", options=BLEND_FUNC_options, id="dst_rgb"},{
                    getter = function ()
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(2, 2)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f then
                            local s = f:sub(1, 1)
                            t.state.BLEND_FUNC = s .. BLEND_FUNC_remapper[value]
                            mv.need_reload = true
                        end
                    end,
                }),
                uiproperty.Combo({label="Alpha Source", options=BLEND_FUNC_options, disable=true, id="src_alpha"}, {
                    getter = function ()
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f then
                            local d = f:sub(4, 4)
                            t.state.BLEND_FUNC = BLEND_FUNC_remapper[value] .. d
                            mv.need_reload = true
                        end
                    end,
                }),
                uiproperty.Combo({label="Alpha Destination", options=BLEND_FUNC_options, disable=true, id="dst_alpha"},{
                    getter = function ()
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f == nil or #f ~= 4 then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.entity)
                        local f = t.state.BLEND_FUNC
                        if f and #f == 4 then
                            local s = f:sub(4, 4)
                            t.state.BLEND_FUNC = s .. BLEND_FUNC_remapper[value]
                            mv.need_reload = true
                        end
                    end,
                }),
            })
        }),
        create_simple_state_ui("Float",{label ="Alpha Reference"}, "ALPHA_REF", mv, 0.0),
        create_simple_state_ui("Float",{label = "Point Size"}, "POINT_SIZE", mv, 0.0),
        create_simple_state_ui("Bool", {label="MSAA"}, "MSAA", mv),
        create_simple_state_ui("Bool", {label="LINE AA"}, "LINEAA", mv),
        create_simple_state_ui("Bool", {label="CONSERVATIVE_RASTER"}, "CONSERVATIVE_RASTER", mv),
        create_simple_state_ui("Bool", {label="Front Face as CCW"}, "FRONT_CCW", mv),
        uiproperty.Group({label="Write Mask"},{
            R = create_write_mask_ui("R", mv),
            G = create_write_mask_ui("G", mv),
            B = create_write_mask_ui("B", mv),
            A = create_write_mask_ui("A", mv),
            Z = create_write_mask_ui("Z", mv),
        }),
        create_simple_state_ui("Combo", {label="Depth Test", options=DEPTH_TEST_options}, "DEPTH_TEST", mv),
        create_simple_state_ui("Combo", {label="Cull Type", options=CULL_options}, "CULL", mv),
    })
end

function MaterialView:_init()
    BaseView._init(self)
    
    self.mat_file       = uiproperty.ResourcePath({label = "File", extension = ".material"},{
        getter = function()
            w:sync("material?in", self.entity)
            return self.entity.material
        end,
        setter = function (value)
            self.entity.material = value
            w:sync("material:out", self.entity)
            self.need_reload = true
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
    self.material = uiproperty.Group({label="Material"},{
        self.mat_file,
        self.fx,
        self.state,
        self.save,
        self.saveas,
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

function MaterialView:set_model(e)
    if not BaseView.set_model(self, e) then 
        return false
    end
    --update ui state
    self.mat_file.disable = is_readonly_resource(tostring(e.material))
    self.properties = build_properties_ui(self)

    local t = material_template(e)
    if t.fx.cs == nil then
        local cs = self.fx:find_property_by_label "cs"
        cs.visible = false
    end

    local s = state_template(e)
    if s then
        local bs = self.state:find_property "blend_setting"
        for _, p in ipairs(bs.subproperty) do
            p.disable = not s.BLEND_ENABLE
        end
        bs:find_property "enable".disable = false
    end

    self.material:set_subproperty{
        self.mat_file,
        self.fx,
        self.properties,
        self.state,
        self.save, self.saveas
    }

    self:update()
    return true
end

function MaterialView:update()
    local e = self.entity
    if e then
        self.material:update()

        if self.need_reload then
            local p = self.mat_file:get_path()
            reload(e, p)
        end
    end
end

function MaterialView:show()
    if self.entity then
        BaseView.show(self)
        self.material:show()
    end

end

return MaterialView