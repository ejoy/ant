local imagefont = {}
local limgfont = require "font.image"

local IMAGE_FONT_MASK<const> = 0x40
local imgid = 0
local function alloc_imgid()
    imgid = imgid + 1
    return IMAGE_FONT_MASK|imgid
end

local function is_imgfont(fontid)
    return 0 ~= (fontid & IMAGE_FONT_MASK)
end

local function unpack_image_data(imgdata)
    local handle, w, h, itemsize, offset = ("<HHHH"):unpack(imgdata)
    local scale, descent, linegap, underline_thickness = ("<ffff"):unpack(imgdata, offset)
    return {
        handle = handle, w = w, h = h, itemsize = itemsize,
        scale = scale, descent = descent, linegap = linegap, underline_thickness = underline_thickness,
        data = imgdata,
    }
end

local import_names = {}
function imagefont.import(name, imgdata)
    print "Import------------"
    if import_names[name] then
        error(("duplicate image font name:%s"):format(name))
    end
    import_names[name] = unpack_image_data(imgdata)
end

local function fetch_imageid(imgs, name)
    local id = alloc_imgid()
    if import_names[name] == nil then
        error (("image font name:%s is not import"):format(name))
    end
    imgs[name] = id
    imgs[id] = name
    return id
end

local image_fontid_names = setmetatable({}, {__index=fetch_imageid})

function imagefont.name(n)
    return image_fontid_names[n]
end

function imagefont.info(fontid)
    assert(is_imgfont(fontid))
    local name = image_fontid_names[fontid]
    local img = assert(import_names[name])
    return img.data
end

local CODEPOINTS = setmetatable({}, {__index=function (t, key)
    local codepoint = 0x00ffffff&key
    local fontid = (0xff000000&key)>>24
    local name = image_fontid_names[fontid]
    local img = assert(import_names[name])
    local w, h = img.w, img.h

    local itemsize = img.itemsize
    local s = codepoint * itemsize
    local uidx, vidx = s // w, s % h
    local u, v = uidx * itemsize, vidx * itemsize
    
    -- struct font_glyph {
    --     int16_t offset_x;
    --     int16_t offset_y;
    --     int16_t advance_x;
    --     int16_t advance_y;
    --     uint16_t w;
    --     uint16_t h;
    --     uint16_t u;
    --     uint16_t v;
    -- };
    local ITEM_GAP<const> = 2
    --TODO: advance_x/y need some gap?
    local vv = ("<HHHHHHHH"):pack(
        0, 0, itemsize+ITEM_GAP, itemsize+ITEM_GAP,
        itemsize, itemsize, u, v
    )
    t[key] = vv
    return vv
end})

function imagefont.codepoint(fontid, codepoint)
    assert(is_imgfont(fontid))
    local key = fontid << 24|codepoint
    local v = CODEPOINTS[key]
    return v
end

limgfont.IMPORT     = imagefont.import
limgfont.IMG_INFO   = imagefont.info
limgfont.CODEPOINT  = imagefont.codepoint
limgfont.NAME       = imagefont.name

return imagefont
