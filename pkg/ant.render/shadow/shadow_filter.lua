local ecs   = ...
local world = ecs.world
local w     = world.w

local mc        = import_package "ant.math".constant
local math3d    = require "math3d"

local setting	= import_package "ant.settings"

local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
if not ENABLE_SHADOW then
    return
end

local FILTER_MODE<const>			= setting:get "graphic/shadow/filter_mode"
if FILTER_MODE ~= "evsm" then
    return 
end

local MSAA_DEPTH<const>         = setting:get "graphic/msaa"
local SMSIZE<const>             = setting:get "graphic/shadow/size"
local EVSMSETTING<const>        = setting:get "graphic/shadow/evsm"
local EVSM_EXPONENTS<const>     = EVSMSETTING.exponents
local EVSM_BIAS<const>          = EVSMSETTING.bias
local EVSM_BLEEDING<const>      = EVSMSETTING.bleeding
local EVSM_KERNELSIZE<const>    = EVSMSETTING.size

local ics                       = require "shadow.csm_split"

local SPLIT_NUM = ics.split_num
local imaterial = ecs.require "ant.render|material"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local irender   = ecs.require "ant.render|render"
local sampler   = import_package "ant.render.core".sampler
local hwi       = import_package "ant.hwi"
local fbmgr     = require "framebuffer_mgr"

local EVSM_RESOLVER<const>, EVSM_H<const>, EVSM_V<const> = 1, 2, 3

local EVSM_STEPS = {}
local last_viewidname = "evsm"
for i=1, SPLIT_NUM do
    local blurh_name = "evsm_blurh" .. i
    local blurh_viewid = hwi.viewid_generate(blurh_name, last_viewidname)
    last_viewidname = blurh_name

    local blurv_name = "evsm_blurv" .. i
    local blurv_viewid = hwi.viewid_generate(blurv_name, last_viewidname)
    last_viewidname = blurv_name

    local resolver_name = "evsm_resolver" .. i
    local resolver_viewid = hwi.viewid_generate(resolver_name, last_viewidname)
    last_viewidname = resolver_name

    EVSM_STEPS[#EVSM_STEPS+1] = {
        [EVSM_RESOLVER] = {
            viewid      = resolver_viewid,
            queuename   = resolver_name,
            material    = "/pkg/ant.resources/materials/shadow/evsm_resolve.material",
        },
        [EVSM_H] = {
            viewid      = blurh_viewid,
            queuename   = blurh_name,
            material    = "/pkg/ant.resources/materials/shadow/evsm_blurH.material",
        },
        [EVSM_V] = {
            viewid      = blurv_viewid,
            queuename   = blurv_name,
            material    = "/pkg/ant.resources/materials/shadow/evsm_blurV.material",
        },
    }
end

local function create_queue(name, viewid, fbidx)
    return world:create_entity{
        policy = {
            "ant.render|postprocess_queue",
        },
        data = {
            render_target = {
                viewid = viewid,
                view_rect = {x=0, y=0, w=SMSIZE, h=SMSIZE},
                clear_state = {
                    clear = "",
                },
                fb_idx = fbidx,
            },
            queue_name = name,
            visible = false,    --we do not want be selected by 'visible' tag
        }
    }
end

local function create_drawer(material, onready)
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result = irender.full_quad(),
            material    = material,
            scene       = {},
            on_ready    = onready,
        }
    }
end

local S         = ecs.system "shadow_filter_system"
function S:init()
    for _, s in ipairs(EVSM_STEPS) do
        for _, t in ipairs(s) do
            queuemgr.register_queue(t.queuename)
            t.RENDER_ARG = irender.pack_render_arg(t.queuename, t.viewid)
        end
    end
end

function S:init_world()
    --TODO: if evsm is enable, shadow map should only create a simple 2d texutre, not texture array
    -- then insert a drawer to the last of csm queue, and relove the depth result to evsm texture which is a texture array with split_num layers
    -- then the temp texture should only be a 2d texture, and keep the blurH result, than do the blurV to make the result to evsm texture
    local evsm_texture = fbmgr.create_rb{
		format = "RGBA8",
		w=SMSIZE,
		h=SMSIZE,
		layers=math.max(2, SPLIT_NUM), --walk around bgfx bug, layers == 1, it will not create texture arrays
		flags=sampler{
			RT="RT_ON",
			--LINEAR for pcf2x2 with shadow2DProj in shader
			MIN="LINEAR",
			MAG="LINEAR",
			U="BORDER",
			V="BORDER",
		},
	}

    local blur_temp = fbmgr.create_rb{
		format = "RGBA8",
		w=SMSIZE,
		h=SMSIZE,
		layers=math.max(2, SPLIT_NUM), --walk around bgfx bug, layers == 1, it will not create texture arrays
		flags=sampler{
			RT="RT_ON",
			--LINEAR for pcf2x2 with shadow2DProj in shader
			MIN="LINEAR",
			MAG="LINEAR",
			U="BORDER",
			V="BORDER",
		},
	}

    local function create_fb(rb, refidx)
		return fbmgr.create{
				rbidx   = rb,
				layer   = refidx-1,
				mip     = 0,
				resolve = "",
				access  = "w",
			}
	end

    for e in w:select "csm:in render_target:in" do
        local csm = e.csm
        local index = csm.index

        local step = EVSM_STEPS[index]
        local inputhandle = fbmgr.get_rb(e.render_target.fb_idx, 1).handle

        local resolver = step[EVSM_RESOLVER]
        resolver.drawereid = create_drawer(resolver.material, function (e)
            imaterial.set_property(e, "s_input", inputhandle)
            imaterial.set_property(e, "u_filter_param", math3d.vector(index, 0, EVSM_EXPONENTS[1], EVSM_EXPONENTS[2]))
        end)
        resolver.queueeid = create_queue(resolver.queuename, resolver.viewid, create_fb(evsm_texture, index))

        local blurH = step[EVSM_H]
        blurH.drawereid = create_drawer(blurH.material, function (e)
            imaterial.set_property(e, "s_input", evsm_texture)
            imaterial.set_property(e, "u_filter_param", math3d.vector(index, EVSM_KERNELSIZE, SMSIZE, 0))
        end)
        blurH.queueeid = create_queue(blurH.queuename, blurH.viewid, create_fb(blur_temp, index))

        local blurV = step[EVSM_V]
        blurV.drawereid = create_drawer(blurH.material, function (e)
            imaterial.set_property(e, "s_input", blur_temp)
            imaterial.set_property(e, "u_filter_param", math3d.vector(index, EVSM_KERNELSIZE, SMSIZE, 0))
        end)
        blurV.queueeid = create_queue(blurV.queuename, blurV.viewid, create_fb(evsm_texture, index))
    end

    imaterial.system_attrib_update("u_shadow_filter_param", math3d.vector(EVSM_EXPONENTS[1], EVSM_EXPONENTS[2], EVSM_BIAS, EVSM_BLEEDING))
    imaterial.system_attrib_update("s_shadowmap", evsm_texture)
end

function S:render_submit()
    for _, s in ipairs(EVSM_STEPS) do
        for _, t in ipairs(s) do
            irender.draw(t.RENDER_ARG, t.drawereid)
        end
    end
end

local isf = {}
return isf