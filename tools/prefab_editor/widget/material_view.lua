local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.import.interface "ant.asset|imaterial"

--[[
    TODO:
    It's a WRONG place for material editing.

    We need a **Material Editor** to edit material, not show material file content in entity property tab
]]

local irender     = ecs.import.interface "ant.render|irender"

local prefab_mgr  = ecs.require "prefab_manager"
ecs.require "widget.base_view"

local assetmgr  = import_package "ant.asset"
local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy_edit"

local uiproperty= require "widget.uiproperty"
local view_class= require "widget.view_class"
local global_data=require "common.global_data"

local BaseView, MaterialView = view_class.BaseView, view_class.MaterialView

local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local access    = require "vfs.repoaccess"

local file_cache = {}

local function read_datalist_file(p)
    local c = file_cache[p]
    if c == nil then
        c = serialize.parse(p, cr.read_file(p))
        file_cache[p] = c
    end
    return c
end

local default_setting = read_datalist_file "/pkg/ant.resources/settings/default.setting"

local function material_template(eid)
    local prefab = hierarchy:get_template(eid)
    local mf = prefab.template.data.material
    return read_datalist_file(mf)
end

local function state_template(eid)
    local t = material_template(eid)
    if type(t.state) == "string" then
        return read_datalist_file(t.state)
    end
    return t.state
end

local DEPTH_TYPE_options<const> = {
    "inv_z", "linear"
}

local function build_fx_ui(mv)
    local function shader_file_ui(st)
        return uiproperty.ResourcePath({label=st, extension = ".sc", readonly = true}, {
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
        s = s or default_setting
        return s[which] or default_setting[which]
    end

    local function check_set_setting(n, v)
        local fx = material_template(mv.eid).fx
        local s = fx.setting
        if s == nil then
            s = {}
            fx.setting = s
        end
        s[n] = v
    end

    return uiproperty.Group({label="FX", flags = 0}, {
        shader_file_ui "vs",
        shader_file_ui "fs",
        shader_file_ui "cs",
        uiproperty.Group({label="Setting"},{
            uiproperty.Bool({label="Lighting"}, {
                getter = function() return setting_filed "lighting" == "on" end,
                setter = function (value)
                    check_set_setting("lighting", value and "on" or "off")
                    mv.need_reload = true
                end
            }),
            uiproperty.Combo({label = "Layer", options = irender.layer_names()},{
                getter = function() return setting_filed "surfacetype" end,
                setter = function(value)
                    check_set_setting("surfacetype", value)
                    mv.need_reload = true
                end,
            }),
            uiproperty.Bool({label = "ShadowCast"}, {
                getter = function()
                    local prefab = hierarchy:get_template(mv.eid)
                    local data = prefab.template.data
                    return data.filter_state:match "cast_shadow" ~= nil
                end,
                setter = function(value)
                    local prefab = hierarchy:get_template(mv.eid)
                    local data = prefab.template.data
                local fstate = data.filter_state
                    if value then
                        if not fstate:match "cast_shadow" then
                            data.filter_state = fstate .. "|cast_shadow"
                        end
                    else
                        local ss = {}
                        for n in fstate:gmatch "[%w_]+" do
                            if n ~= "cast_shadow" then
                                ss[#ss+1] = n
                            end
                        end
                        data.filter_state = table.concat(ss, '|')
                    end

                    mv.need_reload = true
                end,
            }),
            uiproperty.Bool({label = "ShadowReceive"}, {
                getter = function () return setting_filed "shadow_receive" == "on" end,
                setter = function(value)
                    check_set_setting("shadow_receive", value and "on" or "off")
                    mv.need_reload = true
                end,
            }),
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
                imaterial.set_property(world:entity(mv.eid), n, pp)
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
                    imaterial.set_property(world:entity(mv.eid), n, pp)
                    mv.need_reload = true
                end
            })
        end
        return uiproperty.Group({label=n}, pp)
    else
        error(("property:%s, not support uniform type:%s"):format(n, tt))
    end
end

local deftex<const> = "/pkg/ant.resources/textures/black.texture"
local default_properties<const> = {
    basecolor = {
        texture = "/pkg/ant.resources/textures/pbr/default/basecolor.texture",
        stage = 0,
        factor = {1, 1, 1, 1},
    },
    metallic_roughness = {
        texture = "/pkg/ant.resources/textures/pbr/default/metallic_roughness.texture",
        stage = 1,
        factor = {1, 0, 0, 0},
    },
    normal = {
        texture = "/pkg/ant.resources/textures/pbr/default/normal.texture",
        stage = 2,
    },
    emissive = {
        texture = "/pkg/ant.resources/textures/pbr/default/emissive.texture",
        stage = 3,
        factor = {0, 0, 0, 0},
    },
    occlusion = {
        texture = "/pkg/ant.resources/textures/pbr/default/occlusion.texture",
        stage = 4,
    }
}

local LIT_options<const> = {
    "lit",
    "unlit",
}

local function get_pbr_factor(t)
    local pbrfactor = t.u_pbr_factor
    if pbrfactor == nil then
        pbrfactor = {1, 1, 0, 0}
        t.u_pbr_factor = pbrfactor
    end

    return pbrfactor
end

local function build_properties_ui(mv)
    local t = material_template(assert(mv.eid))
    local properties = {}
    if is_pbr_material(t) then
        local dp = t.properties

        local function get_properties()
            if dp == nil then
                dp = {}
                t.properties = dp
            end
            
            return dp
        end

        local factor_names<const> = {
            basecolor = "u_basecolor_factor",
            emissive = "u_emissive_factor",
        }
        local function get_factor(n)
            local fn = factor_names[n]
            return dp[fn] or default_properties[n].factor
        end

        local function set_factor(n, f)
            local fn = factor_names[n]
            local p = get_properties()
            p[fn] = f
        end

        local function set_texture(n, value)
            local p = get_properties()
            local sn = "s_" .. n
            if p[sn] == nil then
                p[sn] = {
                    stage = default_properties[n].stage
                }
            end
            p[sn].texture = value
        end

        local function fx_setting(field, value)
            if t.fx.settings then
                if value then
                    t.fx.settings[field] = value
                else
                    return t.fx.settings[field]
                end
            end
        end

        local function property_texture(field, value)
            if t.properties then
                local p = t.properties[field]
                if p then
                    if value then
                        p.texture = value
                    else
                        return p.texture
                    end
                end
            end
        end

        properties[#properties+1] = uiproperty.Combo({label="lit mode", options=LIT_options}, {
            getter = function ()
                return fx_setting "MATERIAL_UNLIT" and "unlit" or "lit"
            end,
            setter = function (value)
                fx_setting("MATERIAL_UNLIT", value == "unlit" and 1 or nil)
            end
        })

        --TODO: need a texture&enable ui control
        local function add_textre_ui(field, parentui, ...)
            local tt = {
                uiproperty.Bool({label="Enable"}, {
                    getter = function ()
                        return property_texture(field) ~= nil
                    end,
                    setter = function (value)
                        local mr = mv.properties:find_property_by_label(parentui)
                        local uitex = mr.subproperty[2]
                        uitex.disable = not value
                    end
                }),
                uiproperty.EditText({label="Texture"},{
                    getter = function ()
                        return property_texture(field)
                    end,
                    setter = function (value)
                        set_texture(field, value)
                    end
                })
            }

            for i=1, select('#', ...) do
                local a = select(i, ...)
                tt[#tt+1] = a
            end
            return tt
        end

        properties[#properties+1] = uiproperty.Group({label="basecolor"},
            add_textre_ui("s_basecolor", "basecolor", 
                uiproperty.Float({label="Factor", dim=4, min=0.0, max=1.0, speed=0.02}, {
                    getter = function ()
                        return get_factor "basecolor"
                    end,
                    setter = function (value)
                        set_factor("basecolor", value)
                        imaterial.set_property(world:entity(mv.eid), "u_basecolor_factor", value)
                    end
                })
            )
        )

        properties[#properties+1] = uiproperty.Group({label="metallic_roughness"}, 
            add_textre_ui("s_metallic_roughness", "metallic_roughness",
                uiproperty.Group({label="Factor", dim=4}, {
                    uiproperty.Float({label="metallic", min=0.0, max=1.0, speed=0.02}, {
                        getter = function ()
                            local pbrfactor = t.u_pbr_factor
                            return pbrfactor and pbrfactor[2] or 0.0
                        end,
                        setter = function (value)
                            local pbrfactor = get_pbr_factor(t)
                            pbrfactor[1] = value
                            imaterial.set_property(world:entity(mv.eid), "u_pbr_factor", pbrfactor)
                        end
                    }),
                    uiproperty.Float({label="roughness", min=0.0, max=1.0, speed=0.02}, {
                        getter = function ()
                            local pbrfactor = t.u_pbr_factor
                            return pbrfactor and pbrfactor[1] or 0.0
                        end,
                        setter = function (value)
                            local pbrfactor = get_pbr_factor(t)
                            pbrfactor[2] = value
                            imaterial.set_property(world:entity(mv.eid), "u_pbr_factor", pbrfactor)
                        end,
                    })
                })
            )
        )

        properties[#properties+1] = uiproperty.Group({label="normal"},
            add_textre_ui("s_normal", "normal"))

        properties[#properties+1] = uiproperty.Group({label="occlusion"},
            add_textre_ui("s_occlusion", "occlusion"))

        properties[#properties+1] = uiproperty.Group({label="emissive"},
            add_textre_ui("s_emissive", "emissive",
            uiproperty.Float({label="Factor", dim=4}, {
                getter = function ()
                    return get_factor "emissive"
                end,
                setter = function (value)
                    set_factor("emissive", value)
                    imaterial.set_property(world:entity(mv.eid), "u_emissive_factor", value)
                end
            })
        ))

        properties[#properties+1] = uiproperty.Group({label="Alpha Cutoff"}, {
            uiproperty.Bool({label ="enable"},{
                getter = function ()
                    return fx_setting "ALPHAMODE_MASK" ~= nil
                end,
                setter = function (value)
                    fx_setting("ALPHAMODE_MASK", value and 1 or nil)
                end
            }),
            uiproperty.Float({label="cutoff value", min=0.0, max=1.0, speed=0.02}, {
                getter = function ()
                    local pbrfactor = t.u_pbr_factor
                    return pbrfactor and pbrfactor[3] or 0.0
                end,
                setter = function (value)
                    local pbrfactor = get_pbr_factor(t)
                    pbrfactor[3] = value
                    imaterial.set_property(world:entity(mv.eid), "u_pbr_factor", pbrfactor)
                end
            })
        })
        

        properties[#properties+1] = uiproperty.Float({label="occlusion strength", min=0.0, max=1.0, speed=0.02},{
            getter = function ()
                local pbrfactor = t.u_pbr_factor
                return pbrfactor and pbrfactor[4] or 0.0
            end,
            setter = function (value)
                local pbrfactor = get_pbr_factor(t)
                pbrfactor[4] = value
                imaterial.set_property(world:entity(mv.eid), "u_pbr_factor", pbrfactor)
            end
        })
    else
        if t.properties then
            for n, p in pairs(t.properties) do
                properties[#properties+1] = create_property_ui(n, p, mv)
            end
        end
    end
    return properties
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
            local s = state_template(mv.eid)
            return s[en] or def_value
        end,
        setter = function (value)
            local s = state_template(mv.eid)
            s[en] = value
            mv.need_reload = true
        end,
    })
end

local function create_write_mask_ui(en, mv)
    return uiproperty.Bool({label=en}, {
        getter = function ()
            local s = state_template(mv.eid)
            return s.WRITE_MASK:match(en)
        end,
        setter = function (value)
            local s = state_template(mv.eid)
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
    return uiproperty.Group({label="State", flags = 0},{
        uiproperty.Combo({label = "Pritmive Type", options=PT_options, id="PT"}, {
            getter = function ()
                local s = state_template(mv.eid)
                return s.PT == nil and "Triangles" or s.PT
            end,
            setter = function(value)
                local s = state_template(mv.eid)
                s.PT = value ~= "Triangles" and value or nil
                mv.need_reload = true
            end
        }),

        uiproperty.Group({label="Blend Setting", id="blend_setting"}, {
            uiproperty.Bool({label="Enable", id="enable"}, {
                getter = function()
                    local s = state_template(mv.eid)
                    return s.BLEND_ENABLE
                end,
                setter = function (value)
                    local s = state_template(mv.eid)
                    s.BLEND_ENABLE = value ~= nil
                    mv:enable_blend_setting_ui(mv.eid)
                    mv.need_reload = true
                end,
            }),
            create_simple_state_ui("Combo",{label="Type", options=BLEND_options, id="type"}, "BLEND", mv, BLEND_options[1]),
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
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(1, 1)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
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
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(2, 2)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
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
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if f == nil then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
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
                        local t = material_template(mv.eid)
                        local f = t.state.BLEND_FUNC
                        if f == nil or #f ~= 4 then
                            return BLEND_FUNC_options[1]
                        end
                        local k = f:sub(3, 3)
                        return BLEND_FUNC_mapper[k]
                    end,
                    setter = function (value)
                        local t = material_template(mv.eid)
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
            create_write_mask_ui("R", mv),
            create_write_mask_ui("G", mv),
            create_write_mask_ui("B", mv),
            create_write_mask_ui("A", mv),
            create_write_mask_ui("Z", mv),
        }),
        create_simple_state_ui("Combo", {label="Depth Test", options=DEPTH_TEST_options}, "DEPTH_TEST", mv),
        create_simple_state_ui("Combo", {label="Cull Type", options=CULL_options}, "CULL", mv),
    })
end

local function save_material(e, path)
    local t = material_template(e)
    local p = t.properties
    if p then
        local pp = {}
        local function is_tex(v)
            return v.texture
        end
        for k, v in pairs(p) do
            pp[k] = v
            if is_tex(v) then
                if fs.path(v.texture):is_relative() then
                    pp[k].texture = serialize.path(v.texture)
                else
                    pp[k].texture = v.texture
                end
            end
        end
        t.properties = pp
    end

    local lpp = path:parent_path():localpath()
    if not lfs.exists(lpp) then
        lfs.create_directories(lpp)
    end
    local f<close> = lfs.open(lpp / path:filename():string(), "w")
    f:write(serialize.stringify(t))
end

local function reload(e, mtl)
    local prefab = hierarchy:get_template(e)
    save_material(e, fs.path(mtl))
    prefab.template.data.material = mtl
    prefab_mgr:save_prefab()
    prefab_mgr:reload()
end

function MaterialView:_init()
    BaseView._init(self)
    
    self.mat_file       = uiproperty.ResourcePath({label = "File", extension = ".material"},{
        getter = function()
            return world:entity(self.eid).material
        end,
        setter = function (value)
            world:entity(self.eid).material = value
            self.need_reload = true
        end,
    })

    self.fx         = build_fx_ui(self)
    self.state      = build_state_ui(self)
    self.save       = uiproperty.Button({label="Save"}, {
        click = function ()
            local path = self.mat_file:get_path()
            reload(self.eid, path)
        end,
    })
    self.saveas     = uiproperty.Button({label="Save As ..."}, {
        click = function ()
            local path = uiutils.get_saveas_path("Material", "material")
            if path then
                local vpath = access.virtualpath(global_data.repo, fs.path(path))
                reload(self.eid, vpath)
                if vpath == self.mat_file:get_path() then
                    assetmgr.unload(vpath)
                end
            end
        end
    })

    self.material = uiproperty.Group({label="Material"},{
        self.mat_file,
        self.fx,
        self.state,
        uiproperty.SameLineContainer({}, {
            self.save, self.saveas,
        })
    })
end

local default_files<const> = {
    ['/pkg/ant.resources/materials/pbr_default.material']       = true,
    ['/pkg/ant.resources/materials/pbr_default_cw.material']    = true,
    ['/pkg/ant.resources/materials/states/default.state']       = true,
    ['/pkg/ant.resources/materials/states/default_cw.state']    = true,
    ['/pkg/ant.resources/materials/states/translucent.state']   = true,
    ['/pkg/ant.resources/materials/states/translucent_cw.state']= true,
}

local function is_readonly_resource(p)
    return p:match ".glb|" or default_files[p]
end

function MaterialView:enable_blend_setting_ui(eid)
    local s = state_template(eid)
    if s then
        local bs = self.state:find_property "blend_setting"
        for _, p in ipairs(bs.subproperty) do
            p.disable = not s.BLEND_ENABLE
        end
        bs:find_property "enable".disable = false
    end
end

function MaterialView:set_model(eid)
    if not BaseView.set_model(self, eid) then 
        return false
    end

    self.mat_file.disable = false
    local t = material_template(eid)
    if t.fx.cs == nil then
        local cs = self.fx:find_property_by_label "cs"
        cs.visible = false
    end

    do
        local idx
        for i, p in ipairs(self.material.subproperty) do
            if self.fx == p then
                idx = i+1
                break
            end
        end
        local ui_pp = build_properties_ui(self)
        if self.properties == nil then
            self.properties = uiproperty.Group({label="Properties", flags = 0}, ui_pp)
            table.insert(self.material.subproperty, idx, self.properties)
        else
            self.properties:set_subproperty(ui_pp)
        end
    end
    self.save.disable = is_readonly_resource(world:entity(eid).material)
    self.material.disable = prefab_mgr:get_current_filename() == nil
    self:enable_blend_setting_ui(eid)
    self:enable_properties_ui(eid)

    self:update()
    return true
end

function MaterialView:enable_properties_ui(eid)
    local t = material_template(eid)
    if is_pbr_material(t) then
        local p_ui = assert(self.material:find_property_by_label "Properties")
        local unlit_mode<const> = t.fx.settings and t.fx.settings.MATERIAL_UNLIT ~= nil or false
        
        local function disable_property(n, disable)
            local p = p_ui:find_property_by_label(n)
            p.disable = disable
        end

        disable_property("normal",            unlit_mode)
        disable_property("metallic_roughness", unlit_mode)
        disable_property("occlusion",         unlit_mode)

        local function disable_texture(n)
            local p = p_ui:find_property_by_label(n)
            local enable_ui = p.subproperty[1]
            local text_ui = p.subproperty[2]
            text_ui.disable = not enable_ui.modifier.getter()
        end
        
        disable_texture "basecolor"
        disable_texture "normal"
        disable_texture "metallic_roughness"
        disable_texture "emissive"
        disable_texture "occlusion"

    end
end

function MaterialView:update()
    if self.eid then
        BaseView.update(self)
        self.material:update()
    end
end

function MaterialView:show()
    if self.eid then
        BaseView.show(self)
        self.material:show()
    end

end

return MaterialView