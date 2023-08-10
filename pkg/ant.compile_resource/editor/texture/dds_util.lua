local util = {}; util.__index = util

local DDPF_ALPHAPIXELS    = 0x00000001 --Texture contains alpha data; dwRGBAlphaBitMask contains valid data.
local DDPF_ALPHA          = 0x00000002 --Used in some older DDS files for alpha channel only uncompressed data (dwRGBBitCount contains the alpha channel bitcount; dwABitMask contains valid data)	
local DDPF_FOURCC         = 0x00000004 --Texture contains compressed RGB data; dwFourCC contains valid data.
local DDPF_RGB            = 0x00000040 --Texture contains uncompressed RGB data; dwRGBBitCount and the RGB masks (dwRBitMask, dwGBitMask, dwBBitMask) contain valid data.	
local DDPF_YUV            = 0x00000200 -- Used in some older DDS files for YUV uncompressed data (dwRGBBitCount contains the YUV bit count; dwRBitMask contains the Y mask, dwGBitMask contains the U mask, dwBBitMask contains the V mask)	
local DDPF_LUMINANCE      = 0x00020000 --Used in some older DDS files for single channel color uncompressed data (dwRGBBitCount contains the luminance channel bit count; dwRBitMask contains the channel mask). Can be combined with DDPF_ALPHAPIXELS for a two channel DDS file.
local DDPF_BUMPDUDV       = 0x00080000

local function MAKEFOURCC(_a, _b, _c, _d) 
    local b1, b2, b3, b4 = _a:byte(), _b:byte(), _c:byte(), _d:byte()
    return b1|(b2 << 8)|(b3 << 16)|(b4 << 24)
end

local DDS_MAGIC = MAKEFOURCC('D', 'D', 'S', ' ')
local DXT1 = MAKEFOURCC('D', 'X', 'T', '1')
local DXT2 = MAKEFOURCC('D', 'X', 'T', '2')
local DXT3 = MAKEFOURCC('D', 'X', 'T', '3')
local DXT4 = MAKEFOURCC('D', 'X', 'T', '4')
local DXT5 = MAKEFOURCC('D', 'X', 'T', '5')
local ATI1 = MAKEFOURCC('A', 'T', 'I', '1')
local BC4U = MAKEFOURCC('B', 'C', '4', 'U')
local ATI2 = MAKEFOURCC('A', 'T', 'I', '2')
local BC5U = MAKEFOURCC('B', 'C', '5', 'U')

local DX10 = MAKEFOURCC('D', 'X', '1', '0')

local DX_COMPRESS_FMT_NAME = {
    [DXT1] = "BC1",
    [DXT2] = "BC2",
    [DXT3] = "BC3",
    [DXT4] = "BC3",
    [DXT5] = "BC3",
    [ATI1] = "BC4",
    [BC4U] = "BC4",
    [ATI2] = "BC5",
    [BC5U] = "BC5",
}

local function create_reader(str)
    local offset = 1
    return function(num)
        if num == nil then
            local v = string.unpack("<I4", str, offset)
            offset = offset + 4
            return v
        else
            local v = {}
            for i=1, num do
                v[i] = string.unpack("<I4", str, offset)
                offset = offset + 4
            end
            return v
        end
    end
end

local read_dword

local function read_pf(str)
    -- struct DDS_PIXELFORMAT {
    --     DWORD dwSize;
    --     DWORD dwFlags;
    --     DWORD dwFourCC;
    --     DWORD dwRGBBitCount;
    --     DWORD dwRBitMask;
    --     DWORD dwGBitMask;
    --     DWORD dwBBitMask;
    --     DWORD dwABitMask;
    --   };
    return {
        size        = read_dword(str),
        flags       = read_dword(str),
        fourCC      = read_dword(str),
        bitcount    = read_dword(str),
        r_bitmask   = read_dword(str),
        g_bitmask   = read_dword(str),
        b_bitmask   = read_dword(str),
        a_bitmask   = read_dword(str),
    }
end

local function read_dx10_header()
        -- typedef struct {
        --     DXGI_FORMAT              dxgiFormat;
        --     D3D10_RESOURCE_DIMENSION resourceDimension;
        --     UINT                     miscFlag;
        --     UINT                     arraySize;
        --     UINT                     miscFlags2;
        --   } DDS_HEADER_DXT10;
        return {
            dxgi_format = read_dword(),
            dimension   = read_dword(),
            misc_flag   = read_dword(),
            array_size  = read_dword(),
            misc_flag2  = read_dword(),
        }
end

local DDS_HEADER_SIZE = 128
local DDS_DX10_HEADER_SIZE = 20

local function load_dds_header(filepath)
    -- typedef struct {
    --     DWORD           dwSize;
    --     DWORD           dwFlags;
    --     DWORD           dwHeight;
    --     DWORD           dwWidth;
    --     DWORD           dwPitchOrLinearSize;
    --     DWORD           dwDepth;
    --     DWORD           dwMipMapCount;
    --     DWORD           dwReserved1[11];
    --     DDS_PIXELFORMAT ddspf;
    --     DWORD           dwCaps;
    --     DWORD           dwCaps2;
    --     DWORD           dwCaps3;
    --     DWORD           dwCaps4;
    --     DWORD           dwReserved2;
    --   } DDS_HEADER;
    local f <close> = assert(io.open(filepath:string(), "rb"))
    read_dword = create_reader(f:read(DDS_HEADER_SIZE))

    local magic = read_dword()
    if magic ~= DDS_MAGIC then
        print("not dds file:", filepath:string())
        return 
    end

    local header = {
        size    = read_dword(),
        flags   = read_dword(),
        height  = read_dword(),
        width   = read_dword(),
        pitch_or_linear_size = read_dword(),
        depth   = read_dword(),
        mipmap_count = read_dword(),
        reserved1= read_dword(11),
        ddspf   = read_pf(),
        caps    = read_dword(),
        caps2   = read_dword(),
        caps3   = read_dword(),
        caps4   = read_dword(),
        reserved2=read_dword(),
    }

    if header.ddspf.fourCC == DX10 then
        read_dword = create_reader(f:read(DDS_DX10_HEADER_SIZE))
        header.ddspf.dx10 = read_dx10_header()
    end
    
    return header
end

local DDS_PIXEL_FORMAT_MAPPER = {
    { bitcount = 8,  flags = DDPF_LUMINANCE,             bitmasks = { 0x000000ff, 0x00000000, 0x00000000, 0x00000000 }, name = "R8"    },
    { bitcount = 16, flags = DDPF_BUMPDUDV,              bitmasks = { 0x000000ff, 0x0000ff00, 0x00000000, 0x00000000 }, name = "RG8S"  },
    { bitcount = 16, flags = DDPF_RGB,                   bitmasks = { 0x0000ffff, 0x00000000, 0x00000000, 0x00000000 }, name = "R16U"  },
    { bitcount = 16, flags = DDPF_RGB|DDPF_ALPHAPIXELS,  bitmasks = { 0x00000f00, 0x000000f0, 0x0000000f, 0x0000f000 }, name = "RGBA4" },
    { bitcount = 16, flags = DDPF_RGB,                   bitmasks = { 0x0000f800, 0x000007e0, 0x0000001f, 0x00000000 }, name = "R5G6B5"},
    { bitcount = 16, flags = DDPF_RGB,                   bitmasks = { 0x00007c00, 0x000003e0, 0x0000001f, 0x00008000 }, name = "RGB5A1"},
    { bitcount = 24, flags = DDPF_RGB,                   bitmasks = { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, name = "RGB8"  },
    { bitcount = 24, flags = DDPF_RGB,                   bitmasks = { 0x000000ff, 0x0000ff00, 0x00ff0000, 0x00000000 }, name = "RGB8"  },
    { bitcount = 32, flags = DDPF_RGB,                   bitmasks = { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, name = "BGRA8" },
    { bitcount = 32, flags = DDPF_RGB|DDPF_ALPHAPIXELS,  bitmasks = { 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 }, name = "RGBA8" },
    { bitcount = 32, flags = DDPF_BUMPDUDV,              bitmasks = { 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 }, name = "RGBA8S"},
    { bitcount = 32, flags = DDPF_RGB,                   bitmasks = { 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000 }, name = "BGRA8" },
    { bitcount = 32, flags = DDPF_RGB|DDPF_ALPHAPIXELS,  bitmasks = { 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000 }, name = "BGRA8" }, -- D3DFMT_A8R8G8B8
    { bitcount = 32, flags = DDPF_RGB|DDPF_ALPHAPIXELS,  bitmasks = { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, name = "BGRA8" }, -- D3DFMT_X8R8G8B8
    { bitcount = 32, flags = DDPF_RGB|DDPF_ALPHAPIXELS,  bitmasks = { 0x000003ff, 0x000ffc00, 0x3ff00000, 0xc0000000 }, name = "RGB10A2"},
    { bitcount = 32, flags = DDPF_RGB,                   bitmasks = { 0x0000ffff, 0xffff0000, 0x00000000, 0x00000000 }, name = "RG16"  },
    { bitcount = 32, flags = DDPF_BUMPDUDV,              bitmasks = { 0x0000ffff, 0xffff0000, 0x00000000, 0x00000000 }, name = "RG16S" },
    { bitcount = 32, flags = DDPF_RGB,                   bitmasks = { 0xffffffff, 0x00000000, 0x00000000, 0x00000000 }, name = "R32U"},
}

-- DXGI format
local DDS_FORMAT_R32G32B32A32_FLOAT = 2
local DDS_FORMAT_R32G32B32A32_UINT = 3
local DDS_FORMAT_R16G16B16A16_FLOAT = 10
local DDS_FORMAT_R16G16B16A16_UNORM = 11
local DDS_FORMAT_R16G16B16A16_UINT = 12
local DDS_FORMAT_R32G32_FLOAT = 16
local DDS_FORMAT_R32G32_UINT = 17
local DDS_FORMAT_R10G10B10A2_UNORM = 24
local DDS_FORMAT_R11G11B10_FLOAT = 26
local DDS_FORMAT_R8G8B8A8_UNORM = 28
local DDS_FORMAT_R8G8B8A8_UNORM_SRGB = 29
local DDS_FORMAT_R16G16_FLOAT = 34
local DDS_FORMAT_R16G16_UNORM = 35
local DDS_FORMAT_R32_FLOAT = 41
local DDS_FORMAT_R32_UINT = 42
local DDS_FORMAT_R8G8_UNORM = 49
local DDS_FORMAT_R16_FLOAT = 54
local DDS_FORMAT_R16_UNORM = 56
local DDS_FORMAT_R8_UNORM = 61
local DDS_FORMAT_R1_UNORM = 66
local DDS_FORMAT_BC1_UNORM = 71
local DDS_FORMAT_BC1_UNORM_SRGB = 72
local DDS_FORMAT_BC2_UNORM = 74
local DDS_FORMAT_BC2_UNORM_SRGB = 75
local DDS_FORMAT_BC3_UNORM = 77
local DDS_FORMAT_BC3_UNORM_SRGB = 78
local DDS_FORMAT_BC4_UNORM = 80
local DDS_FORMAT_BC5_UNORM = 83
local DDS_FORMAT_B5G6R5_UNORM = 85
local DDS_FORMAT_B5G5R5A1_UNORM = 86
local DDS_FORMAT_B8G8R8A8_UNORM = 87
local DDS_FORMAT_B8G8R8A8_UNORM_SRGB = 91
local DDS_FORMAT_BC6H_SF16 = 96
local DDS_FORMAT_BC7_UNORM = 98
local DDS_FORMAT_BC7_UNORM_SRGB = 99
local DDS_FORMAT_B4G4R4A4_UNORM = 115

local DDS_DXGI_FORMAT_MAPPER = {
  [DDS_FORMAT_BC1_UNORM]          = { "BC1",        false,  true,},
  [DDS_FORMAT_BC1_UNORM_SRGB]     = { "BC1",        true,   true,},
  [DDS_FORMAT_BC2_UNORM]          = { "BC2",        false,  true,},
  [DDS_FORMAT_BC2_UNORM_SRGB]     = { "BC2",        true  , true,},
  [DDS_FORMAT_BC3_UNORM]          = { "BC3",        false , true,},
  [DDS_FORMAT_BC3_UNORM_SRGB]     = { "BC3",        true  , true,},
  [DDS_FORMAT_BC4_UNORM]          = { "BC4",        false , true,},
  [DDS_FORMAT_BC5_UNORM]          = { "BC5",        false , true,},
  [DDS_FORMAT_BC6H_SF16]          = { "BC6H",       false , true,},
  [DDS_FORMAT_BC7_UNORM]          = { "BC7",        false , true,},
  [DDS_FORMAT_BC7_UNORM_SRGB]     = { "BC7",        true  , true,},

  [DDS_FORMAT_R1_UNORM]           = { "R1",         false , false,},
  [DDS_FORMAT_R8_UNORM]           = { "R8",         false , false,},
  [DDS_FORMAT_R16_UNORM]          = { "R16",        false , false,},
  [DDS_FORMAT_R16_FLOAT]          = { "R16F",       false , false,},
  [DDS_FORMAT_R32_UINT]           = { "R32U",       false , false,},
  [DDS_FORMAT_R32_FLOAT]          = { "R32F",       false , false,},
  [DDS_FORMAT_R8G8_UNORM]         = { "RG8",        false , false,},
  [DDS_FORMAT_R16G16_UNORM]       = { "RG16",       false , false,},
  [DDS_FORMAT_R16G16_FLOAT]       = { "RG16F",      false , false,},
  [DDS_FORMAT_R32G32_UINT]        = { "RG32U",      false , false,},
  [DDS_FORMAT_R32G32_FLOAT]       = { "RG32F",      false , false,},
  [DDS_FORMAT_B8G8R8A8_UNORM]     = { "BGRA8",      false , false,},
  [DDS_FORMAT_B8G8R8A8_UNORM_SRGB]= { "BGRA8",      true  , false,},
  [DDS_FORMAT_R8G8B8A8_UNORM]     = { "RGBA8",      false , false,},
  [DDS_FORMAT_R8G8B8A8_UNORM_SRGB]= { "RGBA8",      true  , false,},
  [DDS_FORMAT_R16G16B16A16_UNORM] = { "RGBA16",     false , false,},
  [DDS_FORMAT_R16G16B16A16_FLOAT] = { "RGBA16F",    false , false,},
  [DDS_FORMAT_R32G32B32A32_UINT]  = { "RGBA32U",    false , false,},
  [DDS_FORMAT_R32G32B32A32_FLOAT] = { "RGBA32F",    false , false,},
  [DDS_FORMAT_B5G6R5_UNORM]       = { "R5G6B5",     false , false,},
  [DDS_FORMAT_B4G4R4A4_UNORM]     = { "RGBA4",      false , false,},
  [DDS_FORMAT_B5G5R5A1_UNORM]     = { "RGB5A1",     false , false,},
  [DDS_FORMAT_R10G10B10A2_UNORM]  = { "RGB10A2",    false , false,},
  [DDS_FORMAT_R11G11B10_FLOAT]    = { "RG11B10F",   false , false,},
}

local function find_uncompress_format_name(ddspf)
    for i=1, #DDS_PIXEL_FORMAT_MAPPER do
        local fmt_item = DDS_PIXEL_FORMAT_MAPPER[i]
        if  fmt_item.bitcount == ddspf.bitcount and
            fmt_item.flags == ddspf.flags and
            fmt_item.bitmasks[1] == ddspf.r_bitmask and
            fmt_item.bitmasks[2] == ddspf.g_bitmask and
            fmt_item.bitmasks[3] == ddspf.b_bitmask and
            fmt_item.bitmasks[4] == ddspf.a_bitmask then
                return fmt_item.name, false
        end
    end
end

local function find_compress_format_name(ddspf)
    return assert(DX_COMPRESS_FMT_NAME[ddspf.fourCC]), false
end

function util.dds_format(filepath)
    assert(filepath:extension():string():lower() == ".dds")

    local header = load_dds_header(filepath)
    local ddspf  = header.ddspf

    local r = {}
    local dx10 = ddspf.dx10
    if dx10 then
        local item = DDS_DXGI_FORMAT_MAPPER[dx10.dxgi_format]
        r.format     = item[1]
        r.colorspace = item[2] and "sRGB" or "linear"
        r.compressed = item[3]
    else
        local compressed = (ddspf.fourCC & DDPF_FOURCC) ~= 0
        r.compressed = compressed
        local sRGB
        if compressed then
            r.format, sRGB = find_compress_format_name(ddspf)
        else
            r.format, sRGB = find_uncompress_format_name(ddspf)
        end

        r.colorspace = sRGB and "sRGB" or "linear"
    end

    return r
end


return util