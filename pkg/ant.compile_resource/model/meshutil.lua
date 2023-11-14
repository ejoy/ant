local LAYOUT_NAMES<const> = {
	"POSITION",
	"NORMAL",
	"TANGENT",
	"BITANGENT",
	"COLOR_0",
	"COLOR_1",
	"COLOR_2",
	"COLOR_3",
	"TEXCOORD_0",
	"TEXCOORD_1",
	"TEXCOORD_2",
	"TEXCOORD_3",
	"TEXCOORD_4",
	"TEXCOORD_5",
	"TEXCOORD_6",
	"TEXCOORD_7",
	"JOINTS_0",
	"WEIGHTS_0",
}

-- ant.render/vertexdecl_mgr.lua has defined this mapper, but we won't want to dependent ant.render in this package
local SHORT_NAMES<const> = {
    --defined as glTF and bgfx(different from INDICES/JOINTS and WEIGHTS/WEIGHT)
	POSITION= 'p', NORMAL   = 'n', COLOR = 'c',
	TANGENT = 'T', BITANGENT= 'b', TEXCOORD = 't',
	JOINTS  = 'i', WEIGHTS  = 'w',	-- that is special defines
    BLENDINDICES = 'i', BLENDWEIGHT   = 'w',

    --Same with bgfx defined
    p = "POSITION", n = "NORMAL",   c = "COLOR",
    T = "TANGENT",  b = "BITANGENT",t = "TEXCOORD",
    i = "BLENDINDICES",  w = "BLENDWEIGHT",
}

local PRIMITIVE_MODES<const> = {
    "POINTS",
    "LINES",
    false,          --LINELOOP, not support
    "LINESTRIP",
    "",             --TRIANGLES
    "TRISTRIP",     --TRIANGLE_STRIP
    false,          --TRIANGLE_FAN not support
}

return {
    LAYOUT_NAMES    = LAYOUT_NAMES,
    SHORT_NAMES     = SHORT_NAMES,
    PRIMITIVE_MODES = PRIMITIVE_MODES,
}