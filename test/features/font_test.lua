local ecs = ...
local world = ecs.world
local w = world.w
local fonttest_sys = ecs.system "font_test_system"
local fs = require "filesystem"
local assetmgr = import_package "ant.asset"

local fonttex = "/pkg/ant.test.features/assets/font/1.texture"

local imaterial = ecs.import.interface "ant.asset|imaterial"

local lfont = require "font"
local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr
local layout_desc       = declmgr.correct_layout "p20nii|t20nii|c40niu"
local fontquad_layout   = declmgr.get(layout_desc)

local irender = ecs.import.interface "ant.render|irender"

local function text_start_pos(textw, texth, sx, sy)
    return sx - textw * 0.5, sy - texth * 0.5
end

local DEFAUTL_IMGFONT<const> = {
    descent = 3.0,
    linegap = 2.0,
    underline_thickness = 0.5,
    scale = 1.0,
}

local function build_image_data(img)
    -- struct image_font {
    -- 	uint16_t handle;
    -- 	uint16_t w;
    --  uint16_t h;
    --  uint16_t itemsize;

    --  float descent;
    --  float linegap;
    --  float underline_thickness;
    -- 	float scale;
    -- };
    return ("<HHHHffff"):pack(assert(img.handle)&0xffff, img.w, img.h, img.itemsize,
        img.scale, img.descent, img.linegap, img.underline_thickness)
end

local function load_text_mesh(name, img, description)
    local imgdata = build_image_data(img)
    lfont.import_image_font(name, imgdata)
    local imgfontid = lfont.image_font(name)

    local fontsize = 36
    local textw, texth, num = lfont.prepare_text(img.handle, description, fontsize, imgfontid)
    local sx, sy = 0, 0
    local x, y = text_start_pos(textw, texth, sx, sy)

    local m = bgfx.memory_buffer(num*4 * fontquad_layout.stride)
    lfont.load_text_quad(m, description, x, y, fontsize, 0xff00ff00, imgfontid)

    return {
            vb = {
                start = 0,
                num = num*4,
                handle = bgfx.create_vertex_buffer(m, fontquad_layout.handle)
            }, 
            ib = {
                start = 0,
                num = num * 3 * 2,
                handle = irender.quad_ib(),
            }
    }
end

local function sync_load(imgfile)
    local imgres = assetmgr.resource(imgfile)
    --TODO: need remove
    while imgres.uncomplete do
        require "ltask".sleep(1)
    end
    return imgres
end

local function import_image_font(imgfile)
    local imgres = sync_load(imgfile)
    local info = imgres.texinfo
    return {
        handle      = imgres.handle,
        w           = info.width,
        h           = info.height,
        itemsize    = 64,

        scale       = 1.0,
        descent     = DEFAUTL_IMGFONT.descent,
        linegap     = DEFAUTL_IMGFONT.linegap,
        underline_thickness=DEFAUTL_IMGFONT.underline_thickness,
    }
end

local images = {}

function fonttest_sys.init()
    --ecs.create_instance "/pkg/ant.test.features/assets/entities/fonttest.prefab"
    --TODO: sync load texture here
    local codepoint, codepoint2 = 3, 8
    local description = ("<I"):pack(codepoint, codepoint2)
    local img = import_image_font(fonttex)
    images["default"] = img
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = load_text_mesh("default", img, description),
            material = "/pkg/ant.resources/materials/font/imagefont.material",
            visible_state = "main_view",
            scene = {},
            name = "test_imagefont",
            on_ready = function (e)
                imaterial.set_property(e, "s_tex", img.handle)
            end
        }
    }
end