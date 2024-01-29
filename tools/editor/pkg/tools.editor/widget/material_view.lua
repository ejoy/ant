local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local imaterial = ecs.require "ant.asset|material"

--[[
    TODO:
    It's a WRONG place for material editing.

    We need a **Material Editor** to edit material, not show material file content in entity property tab
]]

local prefab_mgr  = ecs.require "prefab_manager"
local serialize = import_package "ant.serialize"
local aio       = import_package "ant.io"
local assetmgr  = import_package "ant.asset"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy_edit"
local uiproperty= require "widget.uiproperty"
local global_data=require "common.global_data"
local fs        = require "filesystem"
local lfs       = require "bee.filesystem"
local access    = global_data.repo_access
local rb        = ecs.require "widget.resource_browser"

local MaterialView = {}
local file_cache = {}

local function read_datalist_file(p)
    local c = file_cache[p]
    if c == nil then
        local vpath = (p:sub(1, 5) == "/pkg/") and p or global_data:lpath_to_vpath(p)
        c = serialize.parse(p, aio.readall(vpath))
        file_cache[p] = c
    end
    return c
end

local default_setting = read_datalist_file "/pkg/ant.settings/default/graphic_settings.ant"

local function load_material_file(mf)
    return read_datalist_file(mf .. "/source.ant")
end

local function material_template(eid)
    local prefab = hierarchy:get_node_info(eid)
    return load_material_file(prefab.template.data.material)
end

local function state_template(eid)
    local t = material_template(eid)
    if type(t.state) == "string" then
        return read_datalist_file(t.state)
    end
    return t.state
end

local function build_fx_ui(mv)
    local function shader_file_ui(st)
        return uiproperty.EditText({label=st,}, {
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
            uiproperty.Bool({label = "ShadowCast"}, {
                getter = function()
                    local prefab = hierarchy:get_node_info(mv.eid)
                    local data = prefab.template.data
                    return data.visible_state:match "cast_shadow" ~= nil
                end,
                setter = function(value)
                    local prefab = hierarchy:get_node_info(mv.eid)
                    local data = prefab.template.data
                local fstate = data.visible_state
                    if value then
                        if not fstate:match "cast_shadow" then
                            data.visible_state = fstate .. "|cast_shadow"
                        end
                    else
                        local ss = {}
                        for n in fstate:gmatch "[%w_]+" do
                            if n ~= "cast_shadow" then
                                ss[#ss+1] = n
                            end
                        end
                        data.visible_state = table.concat(ss, '|')
                    end

                    mv.need_reload = true
                end,
            }),
            uiproperty.Bool({label = "ShadowReceive"}, {
                getter = function () return setting_filed "receive_shadow" == "on" end,
                setter = function(value)
                    check_set_setting("receive_shadow", value and "on" or "off")
                    mv.need_reload = true
                end,
            }),
        })
    })

end

--TODO: hard code here, just check pbr material for show pbr ui
--should add info in material file to let the ui system know how to show
local function is_pbr_material(t)
    return t.fx.shader_type == "PBR"
end

local function which_property_type(p)
    if p.texture then
        return "texture"
    end

    if p.image then
        return "image"
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
        return uiproperty.ResourcePath({label = n, extension=".texture"}, {
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
    elseif tt == "image" then
        return uiproperty.Group({label = n}, {
            uiproperty.EditText({label="Image"},{
                getter = function ()
                    local t = material_template(mv.eid)
                    return t.properties[n].image
                end,
                setter = function (value)
                    local t = material_template(mv.eid)
                    t.properties[n].image = value
                    mv.need_reload = true
                end,
            }),
            uiproperty.Int({lable="Mip"},{
                getter = function ()
                    local t = material_template(mv.eid)
                    return t.properties[n].mip
                end,
                setter = function (value)
                    local t = material_template(mv.eid)
                    t.properties[n].mip = value
                    mv.need_reload = true
                end,
            }),
            uiproperty.EditText({label="Access"},{
                getter = function ()
                    local t = material_template(mv.eid)
                    return t.properties[n].access
                end,
                setter = function (value)
                    local t = material_template(mv.eid)
                    t.properties[n].access = value
                    mv.need_reload = true
                end,
            })
        })
    elseif tt == "v4" or tt == "m4" then
        return uiproperty.Float({label=n, dim=4, min=0.0, max=1.0, speed=0.01}, {
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
                local e <close> = world:entity(mv.eid)
                imaterial.set_property(e, n, math3d.vector(pp))
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
                    local e <close> = world:entity(mv.eid)
                    imaterial.set_property(e, n, math3d.vector(pp))
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

local image_info = {}
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
            if t.fx.setting then
                if value then
                    t.fx.setting[field] = value
                else
                    return t.fx.setting[field]
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
            if property_texture(field) then
                tt[#tt + 1] = uiproperty.Int({label="MaxSize"}, {
                    getter = function ()
                        local tp = property_texture(field)
                        return image_info[tp].height
                    end,
                    setter = function (value)
                        local tp = property_texture(field)
                        image_info[tp].height = value
                        prefab_mgr:do_image_patch(tp, "/maxsize", value)
                    end
                })
            end
            for i=1, select('#', ...) do
                local a = select(i, ...)
                tt[#tt+1] = a
            end
            return tt
        end

        local function create_uvmotion_ui()
            local function update_uvmotion_in_material(u)
                local e <close> = world:entity(mv.eid, "render_object:in")
                local m = e.render_object.material
                m.u_uvmotion = math3d.vector(u)
            end

            local function get_uvmotion()
                local p = get_properties()
                local u = p.u_uvmotion
                if u == nil then
                    return {0, 0, 1, 1}
                end
                return u
            end
            local uvmotion = uiproperty.Group({mode="label_right", label="UV Motion"}, {
                uiproperty.Float({label="Speed", speed=0.005, dim=2}, {
                    getter = function()
                        local u = get_uvmotion()
                        return {u[1], u[2]}
                    end,
                    setter = function (value)
                        local u = get_properties().u_uvmotion
                        u[1], u[2] = value[1], value[2]
                        update_uvmotion_in_material(u)
                    end,
                }),
                uiproperty.Float({label="Tile", speed=0.005, dim=2}, {
                    getter = function ()
                        local u = get_uvmotion()
                        return {u[3], u[4]}
                    end,
                    setter = function (value)
                        local u = get_properties().u_uvmotion
                        u[3], u[4] = value[1], value[2]
                        update_uvmotion_in_material(u)
                    end,
                })
            })
            uvmotion.disable = fx_setting "uv_motion" == true
            return uiproperty.SameLineContainer({id="uv_motion"}, {
                uiproperty.Bool({mode="label_right", label="##", id="uvm_check"},{
                    getter = function ()
                        return fx_setting "uv_motion" == true
                    end,
                    setter = function (value)
                        uvmotion.disable = not value
                        if value then
                            fx_setting("uv_motion", true)
                            local p = get_properties()
                            if p.u_uvmotion == nil then
                                p.u_uvmotion = {0.0, 0.0, 1.0, 1.0}
                            end
                        else
                            fx_setting("uv_motion", nil)
                        end
                    end,
                }),
                uvmotion,
            })
        end

        properties[#properties+1] = create_uvmotion_ui()

        properties[#properties+1] = uiproperty.Group({label="basecolor"},
            add_textre_ui("s_basecolor", "basecolor", 
                uiproperty.Float({label="Factor", dim=4, min=0.0, max=1.0, speed=0.01}, {
                    getter = function ()
                        return get_factor "basecolor"
                    end,
                    setter = function (value)
                        set_factor("basecolor", value)
                        local e <close> = world:entity(mv.eid)
                        imaterial.set_property(e, "u_basecolor_factor", math3d.vector(value))
                        prefab_mgr:do_material_patch(mv.eid, "/properties/u_basecolor_factor", value)
                    end
                })
            )
        )

        properties[#properties+1] = uiproperty.Group({label="metallic_roughness"}, 
            add_textre_ui("s_metallic_roughness", "metallic_roughness",
                uiproperty.Group({label="Factor", dim=4}, {
                    uiproperty.Float({label="metallic", min=0.0, max=1.0, speed=0.01}, {
                        getter = function ()
                            local pbrfactor = t.u_pbr_factor
                            return pbrfactor and pbrfactor[2] or 0.0
                        end,
                        setter = function (value)
                            local pbrfactor = get_pbr_factor(t)
                            pbrfactor[1] = value
                            local e <close> = world:entity(mv.eid)
                            imaterial.set_property(e, "u_pbr_factor", math3d.vector(pbrfactor))
                            prefab_mgr:do_material_patch(mv.eid, "/properties/u_pbr_factor", pbrfactor)
                        end
                    }),
                    uiproperty.Float({label="roughness", min=0.0, max=1.0, speed=0.01}, {
                        getter = function ()
                            local pbrfactor = t.u_pbr_factor
                            return pbrfactor and pbrfactor[1] or 0.0
                        end,
                        setter = function (value)
                            local pbrfactor = get_pbr_factor(t)
                            pbrfactor[2] = value
                            local e <close> = world:entity(mv.eid)
                            imaterial.set_property(e, "u_pbr_factor", math3d.vector(pbrfactor))
                            prefab_mgr:do_material_patch(mv.eid, "/properties/u_pbr_factor", pbrfactor)
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
                    local e <close> = world:entity(mv.eid)
                    imaterial.set_property(e, "u_emissive_factor", math3d.vector(value))
                    prefab_mgr:do_material_patch(mv.eid, "/properties/u_emissive_factor", value)
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
            uiproperty.Float({label="cutoff value", min=0.0, max=1.0, speed=0.01}, {
                getter = function ()
                    local pbrfactor = t.u_pbr_factor
                    return pbrfactor and pbrfactor[3] or 0.0
                end,
                setter = function (value)
                    local pbrfactor = get_pbr_factor(t)
                    pbrfactor[3] = value
                    local e <close> = world:entity(mv.eid)
                    imaterial.set_property(e, "u_pbr_factor", math3d.vector(pbrfactor))
                end
            })
        })
        

        properties[#properties+1] = uiproperty.Float({label="occlusion strength", min=0.0, max=1.0, speed=0.01},{
            getter = function ()
                local pbrfactor = t.u_pbr_factor
                return pbrfactor and pbrfactor[4] or 0.0
            end,
            setter = function (value)
                local pbrfactor = get_pbr_factor(t)
                pbrfactor[4] = value
                local e <close> = world:entity(mv.eid)
                imaterial.set_property(e, "u_pbr_factor", math3d.vector(pbrfactor))
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

local NOT_SET<const> = "[NOT_SET]"

local BLEND_options<const> = {
    NOT_SET,
    "ALPHA",
    "ADD",
    "DARKEN",
    "LIGHTEN",
    "MULTIPLY",
    "NORMAL",
    "SCREEN",
    "LINEAR_BURN",
}

local BLEND_ENABLE_options<const> = {
    NOT_SET,
    "INDEPENDENT",
    "ALPHA_TO_COVERAGE",
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
            if en == "CULL" then
                prefab_mgr:do_material_patch(mv.eid, "/state/CULL", value)
            end
        end,
    })
end

local function create_simple_combo_ui(label, options, id, name, mv)
    return uiproperty.Combo({label=label, options=options, id}, {
        getter = function ()
            local s = state_template(mv.eid)
            return s[name] or NOT_SET
        end,
        setter = function (value)
            local s = state_template(mv.eid)
            if value == NOT_SET then
                s[name] = nil
            else
                s[name] = value
            end
            mv.need_reload = true
        end
    })
end

local function create_blend_function_ui(mv)
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
            --TODO: just use BLEND state, not implement detail blend setting here
            --create_simple_state_ui("Combo",{label="BlendEnable", options=BLEND_ENABLE_options, id="blend_enable"}, "BLEND_ENABLE", mv, "NOT_SET"),
            --create_simple_state_ui("Combo",{label="Equation", id="equation",options=BLEND_EQUATION_options}, "BLEND_EQUATION", mv, BLEND_EQUATION_options[1]),
            create_simple_combo_ui("Type", BLEND_options, "type", "BLEND", mv),
            --create_blend_function_ui(mv)
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

local function check_relative_path(path, basepath)
    if path:is_relative() then
        if not fs.exists(basepath / path) then
            error(("base path: %s, relative resource path: %s, is not valid"):format(basepath:string(), path:string()))
        end
    else
        if not fs.exists(path) then
            error(("Invalid resource path:%s"):format(path:string()))
        end
    end
end

local function save_material(eid, path)
    local t = material_template(eid)

    local function refine_properties(p)
        if p then
            local pp = {}
            local function is_tex(v)
                return v.texture
            end
            for k, v in pairs(p) do
                pp[k] = v
                if is_tex(v) then
                    local texpath = fs.path(v.texture)
                    check_relative_path(texpath, path)
                    pp[k].texture =  texpath:is_relative() and serialize.path(v.texture) or v.texture
                end
            end
            return pp
        end
    end

    local nt = {
        fx = t.fx,
        state = t.state,
        properties = refine_properties(t.properties),
    }

    local lpp = path:parent_path():localpath()
    if not lfs.exists(lpp) then
        lfs.create_directories(lpp)
    end
    local f<close> = assert(io.open((lpp / path:filename()):string(), "w"))
    f:write(serialize.stringify(nt))
end

local function reload(e, mpath)
    local prefab = hierarchy:get_node_info(e)
    prefab.template.data.material = mpath:string()
    prefab_mgr:save()
    prefab_mgr:reload()
end

local function check_disable_file_fetch_ui(matfile_ui)
    local fetch = matfile_ui:find_property "fetch_material"
    local f = rb.selected_file()
    fetch.disable = f == nil or (not f:equal_extension ".material")
end

local default_files<const> = {
    ['/pkg/ant.resources/materials/pbr_default.material']       = true,
    ['/pkg/ant.resources/materials/pbr_default_cw.material']    = true,
    ['/pkg/ant.resources/materials/states/default.state']       = true,
    ['/pkg/ant.resources/materials/states/default_cw.state']    = true,
    ['/pkg/ant.resources/materials/states/translucent.state']   = true,
    ['/pkg/ant.resources/materials/states/translucent_cw.state']= true,
}

local function is_glb_resource()
    local cp = prefab_mgr:get_current_filename()
    if cp then
        return cp:match "%.glb%|mesh%.prefab$" or cp:match "%.gltf%|mesh%.prefab$"
    end
end


local function is_readonly_resource(p)
    if is_glb_resource() then
        return true
    end
    return p:match ".glb|" or p:match ".gltf|" or default_files[p]
end

local function to_virtualpath(localpath)
    local vpath = access.virtualpath(global_data.repo, localpath)
    if vpath == nil then
        error(("save path:%s, is not valid package"):format(localpath))
    end
    assert(false)
    if not vpath:match "/pkg" then
        return fs.path(global_data.package_path:string() .. vpath)
    end
end

local function refine_material_data(eid, newmaterial_path)
    local prefab = hierarchy:get_node_info(eid)
    local oldmaterial_path = fs.path(prefab.template.data.material)
    if oldmaterial_path ~= newmaterial_path then
        local basepath = oldmaterial_path:parent_path()
        local t = load_material_file(oldmaterial_path:string())
        for k, p in pairs(t.properties) do
            if p.texture then
                local texpath = fs.path(p.texture)
                if texpath:is_relative() then
                    p.texture = (basepath / texpath):string()
                end
            end
        end
    end
end

function MaterialView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.mat_file = uiproperty.ResourcePath({label="MaterialFile", extension=".material"}, {
        getter = function()
            local prefab = hierarchy:get_node_info(self.eid)
            return prefab.template.data.material
        end,
        setter = function (value)
            local prefab = hierarchy:get_node_info(self.eid)
            prefab.template.data.material = value
            self.need_reload = true
        end,
    })
    self.fx         = build_fx_ui(self)
    self.state      = build_state_ui(self)
    self.save       = uiproperty.Button({label="Save", sameline = true}, {
        click = function ()
            -- local p = self.mat_file:find_property "path"
            local filepath = fs.path(self.mat_file:value())
            check_relative_path(filepath, prefab_mgr:get_current_filename())
            save_material(self.eid, filepath)
            reload(self.eid, filepath)
        end,
    })
    self.saveas     = uiproperty.Button({label="Save As ..."}, {
        click = function ()
            local path = uiutils.get_saveas_path("Material", "material")
            if path then
                local vpath = to_virtualpath(path)
                refine_material_data(self.eid, vpath)
                save_material(self.eid, vpath)
                reload(self.eid, vpath)
            end
        end
    })

    self.material = uiproperty.Group({label="Material"},{
        self.mat_file,
        self.fx,
        self.state,
        self.save, self.saveas,
    })
end
local texture_flag = {}
local datalist   = require "datalist"
local function split(str)
    local r = {}
    str:gsub('[^|]*', function (wd) r[#r+1] = wd end)
    return r
end
local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/|]*$" .. (path:match "^%./(.+)$" or path)
end
function MaterialView:set_eid(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "filter_material?in render_object?in")
    if not e.filter_material and not e.render_object then
        self.eid = nil
        return
    end
    self.eid = eid

    local t = material_template(self.eid)
    if t.fx.cs == nil then
        local cs = self.fx:find_property_by_label "cs"
        cs.visible = false
    end

    local mtlpath = hierarchy:get_node_info(self.eid).template.data.material
    for _, v in pairs(t.properties) do
        if v.texture and not texture_flag[v.texture] then
            local imagepath = fs.path(absolute_path(v.texture, mtlpath)):normalize()
            local tp = imagepath:string() .. "/source.ant"
            local data = datalist.parse(aio.readall(tp))
            if data and not image_info[v.texture] then
                image_info[v.texture] = {width = data.info.width, height = data.info.height}
                texture_flag[imagepath] = assetmgr.resource(imagepath:string())
            end
        end
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

    local readonly_res = is_readonly_resource(mtlpath)
    self.save.disable = readonly_res
    self.saveas.disable = is_glb_resource()
    self.material.disable = prefab_mgr:get_current_filename() == nil
    self:enable_properties_ui()
    self:update()
end

function MaterialView:clear()
    image_info = {}
    texture_flag = {}
end

function MaterialView:update()
    if not self.eid then
        return
    end
    self.material:update()
end

function MaterialView:enable_properties_ui()
    local t = material_template(self.eid)
    if is_pbr_material(t) then
        local p_ui = assert(self.material:find_property_by_label "Properties")
        local function is_unlit()
            if t.fx.setting  then
                return t.fx.setting.lighting == "off"
            end
        end
        local unlit_mode<const> = is_unlit()
        
        local function disable_property(n, disable)
            local p = p_ui:find_property_by_label(n)
            p.disable = disable
        end

        disable_property("normal",            unlit_mode)
        disable_property("metallic_roughness", unlit_mode)
        disable_property("occlusion",         unlit_mode)

        local function check_enable_texture_ui(n)
            local p = p_ui:find_property_by_label(n)
            local enable_ui = p.subproperty[1]
            local text_ui = p.subproperty[2]
            text_ui.disable = not enable_ui.modifier.getter()
        end
        
        check_enable_texture_ui "basecolor"
        check_enable_texture_ui "normal"
        check_enable_texture_ui "metallic_roughness"
        check_enable_texture_ui "emissive"
        check_enable_texture_ui "occlusion"

    end
end
local filewatch_event = world:sub {"FileWatch"}

function MaterialView:show()
    if not self.eid then
        return
    end
    -- check_disable_file_fetch_ui(self.mat_file)
    for _, _, filename in filewatch_event:unpack() do
        local tname = fs.path(filename):filename():string():gsub(".png", ".texture")
        local path
        for k, _ in pairs(texture_flag) do
            if k:filename():string() == tname then
                path = k
                break
            end
        end
        if path then
            texture_flag[path] = assetmgr.reload(path:string())
            local e <close> = world:entity(self.eid)
            imaterial.set_property(e, "s_basecolor", assetmgr.textures[texture_flag[path].id])
        end
    end
    self.material:show()
end

return function ()
    MaterialView:_init()
    return MaterialView
end