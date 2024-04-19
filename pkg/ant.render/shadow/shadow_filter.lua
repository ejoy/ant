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
local EVSM_SAMPLE_RADIUS<const> = EVSMSETTING.sample_radius
local EVSM_SM_FORMAT<const>     = EVSMSETTING.format

local function check_evsm_exponents()
    --math.log(max_half()) * 0.5f;
    --math.log(max_float()) * 0.5f;
    local VALID_FMT<const> = {
        RGBA16F = 5.54,
        RG16F   = 5.54,
        RGBA32F = 42,
        RG32F   = 42,
    }
    local MAX_EXPONENT = VALID_FMT[EVSM_SM_FORMAT] or error(("Invalid evsm shadowmap format:%s, should only be: [RGBA16F/RGBA32F/RG16F/RG32F] is valid"):format(EVSM_SM_FORMAT))
    EVSM_EXPONENTS[1] = math.min(MAX_EXPONENT, EVSM_EXPONENTS[1])
    EVSM_EXPONENTS[2] = math.min(MAX_EXPONENT, EVSM_EXPONENTS[2])

    log.info("Evsm texture format:%s, positive exponent:%f, negative exponent:%f", EVSM_SM_FORMAT, EVSM_EXPONENTS[1], EVSM_EXPONENTS[2])
end

check_evsm_exponents()

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

local function gen_viewid(basename, idx)
    local name = basename .. idx
    local viewid = hwi.viewid_get(name)
    if not viewid then
        viewid = hwi.viewid_generate(name, last_viewidname)
    end
    
    last_viewidname = name
    return name, viewid
end

for i=1, SPLIT_NUM do
    local resolver_name, resolver_viewid = gen_viewid("evsm_resolver", i)
    local blurh_name, blurh_viewid = gen_viewid("evsm_blurh", i)
    local blurv_name, blurv_viewid = gen_viewid("evsm_blurv", i)

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
                clear_state = {clear = "", },
                fb_idx = fbidx,
            },
            queue_name = name,
            visible = false,    --we do not want be selected by 'visible' tag
        }
    }
end

local function create_drawer(material, inputhandle, param)
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result = irender.full_quad(),
            material    = material,
            scene       = {},
            on_ready    = function (e)
                imaterial.set_property(e, "s_input", inputhandle)
                imaterial.set_property(e, "u_filter_param", param)
            end
        }
    }
end

local S = ecs.system "shadow_filter_system"

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
		format = EVSM_SM_FORMAT,
		w=SMSIZE,
		h=SMSIZE,
		layers=math.max(2, SPLIT_NUM), --walk around bgfx bug, layers == 1, it will not create texture arrays
		flags=sampler{
			RT="RT_ON",
			--LINEAR for pcf2x2 with shadow2DProj in shader
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		},
	}

    local evsm_texture_handle = fbmgr.get_rb(evsm_texture).handle

    local blur_temp = fbmgr.create_rb{
		format = EVSM_SM_FORMAT,
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
    local blur_temp_handle = fbmgr.get_rb(blur_temp).handle

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
        local layeridx = index-1    --base0
        local step = EVSM_STEPS[index]
        local inputhandle = fbmgr.get_rb(e.render_target.fb_idx, 1).handle

        local resolver = step[EVSM_RESOLVER]
        resolver.drawereid  = create_drawer(resolver.material, inputhandle, math3d.vector(layeridx, SMSIZE, EVSM_EXPONENTS[1], EVSM_EXPONENTS[2]))
        resolver.queueeid   = create_queue(resolver.queuename, resolver.viewid, create_fb(evsm_texture, index))

        local blurparam = math3d.vector(layeridx, SMSIZE, EVSM_SAMPLE_RADIUS, 0)
        local blurH = step[EVSM_H]
        blurH.drawereid = create_drawer(blurH.material, evsm_texture_handle, blurparam)
        blurH.queueeid  = create_queue(blurH.queuename, blurH.viewid, create_fb(blur_temp, index))

        local blurV = step[EVSM_V]
        blurV.drawereid = create_drawer(blurV.material, blur_temp_handle, blurparam)
        blurV.queueeid  = create_queue(blurV.queuename, blurV.viewid, create_fb(evsm_texture, index))
    end

    local depthscale = EVSM_BIAS * 0.01
    imaterial.system_attrib_update("u_shadow_filter_param", math3d.vector(EVSM_EXPONENTS[1], EVSM_EXPONENTS[2], depthscale, EVSM_BLEEDING))
    imaterial.system_attrib_update("s_shadowmap", evsm_texture_handle)
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