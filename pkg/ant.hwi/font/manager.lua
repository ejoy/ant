local ttf = require "font.truetype"
local fastio = require "fastio"

local MAXFONT <const> = 64

local namelist = {}

local CACHE = {}

local function utf16toutf8(s)
	local surrogate
	return (s:gsub("..", function(utf16)
		local cp = string.unpack(">H", utf16)
		if (cp & 0xFC00) == 0xD800 then
			surrogate = cp
			return ""
		else
			if surrogate then
				cp = ((surrogate - 0xD800) << 10) + (cp - 0xDC00) + 0x10000
				surrogate = nil
			end
			return utf8.char(cp)
		end
	end))
end

local ids = {
	UNICODE = {
		id = 0,
		encoding = {
			UNICODE_1_0 = 0,
			UNICODE_1_1 = 1,
			ISO_10646 = 2,
			UNICODE_2_0_BMP = 3,
			UNICODE_2_0_FULL = 4,
		},
		lang = { default = 0 },
	},
	-- todo: STBTT_PLATFORM_ID_MAC
	MICROSOFT = {
		id = 3,
		encoding = {
			UNICODE_BMP = 1,
			UNICODE_FULL = 10,
		},
		lang = {
			ENGLISH     =0x0409,
			CHINESE     =0x0804,
			DUTCH       =0x0413,
			FRENCH      =0x040c,
			GERMAN      =0x0407,
			HEBREW      =0x040d,
			ITALIAN     =0x0410,
			JAPANESE    =0x0411,
			KOREAN      =0x0412,
			RUSSIAN     =0x0419,
			SPANISH     =0x0409,
			SWEDISH     =0x041D,
		},
	},
}

local function import(fontdata)
	fontdata = fastio.tostring(fontdata)
	local index = 0
	local cache = {}
	while true do
		for _, obj in pairs(ids) do
			for _, encoding_id in pairs(obj.encoding) do
				for _, lang_id in pairs(obj.lang) do
					local fname, sname = ttf.namestring(fontdata, index, obj.id, encoding_id, lang_id)
					if fname then
						fname = utf16toutf8(fname)
						sname = utf16toutf8(sname)
						local fullname = fname .. " " .. sname
						if not cache[fullname] then
							cache[fullname] = true
							table.insert(namelist, {
								fontdata = fontdata,
								index = index,
								family = string.lower(fname),
								sfamily = string.lower(sname),	-- sub family name
								name = fullname,
							})
						end
					elseif fname == nil then
						return
					end
				end
			end
		end
		index = index + 1
	end
end

local FONT_ID = 0
local function alloc_fontid()
	FONT_ID = FONT_ID + 1
	assert(FONT_ID <= MAXFONT)
	return FONT_ID
end

local function matching(obj, name)
	if obj.family == name or obj.name == name then
		return true
	end
end

local function fetch_name(nametable, name_)
	local name = string.lower(name_)
	for _, obj in ipairs(namelist) do
		if matching(obj, name) then
			if not obj.id then
				obj.id = alloc_fontid()
				CACHE[obj.id] = obj
			end

			local id = obj.id
			nametable[name_] = id
			return id
		end
	end
end

setmetatable(ttf.nametable, { __index = fetch_name })

local function fetch_id(_, id)
	local obj = assert(CACHE[id])
	return ttf.update(id, obj.fontdata, obj.index)
end

setmetatable(ttf.idtable, { __index = fetch_id })

debug.getregistry().TRUETYPE_IMPORT = import
