local ttf = require "font.truetype"
local font = {}

local MAXFONT <const> = 64

function font.loader(filename)
	print ("Load", filename)
	local f = assert(io.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

font.namelist = {}

local function utf16toutf8(s)
	-- todo: surrogate (font name barely use surrogate)
	return (s:gsub("..", function(utf16)
		local cp = string.unpack(">H", utf16)
		return utf8.char(cp)
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

function font.import(filename)
	local data = font.loader(filename)
	local index = 0
	local cache = {}
	while true do
		for plat_name, obj in pairs(ids) do
			for encoding_name, encoding_id in pairs(obj.encoding) do
				for lang_name, lang_id in pairs(obj.lang) do
					local fname, sname = ttf.namestring(data, index, obj.id, encoding_id, lang_id)
					if fname then
						fname = utf16toutf8(fname)
						sname = utf16toutf8(sname)
						local full = fname .. " " .. sname
						if not cache[full] then
							cache[full] = true
							table.insert(font.namelist, {
								filename = filename,
								index = index,
								key = filename .. ":" .. index,
								family = string.lower(fname),
								sfamily = string.lower(sname),	-- sub family name
								name = fname .. " " .. sname,
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

--	id -> filename:index
--	filename -> content
--	filename:index -> { filename: index: id: }
local CACHE = {}

function font.unload(filename)
	local c = CACHE[filename]
	if c then
		local removed = {}
		CACHE[filename] = nil
		for key, obj in pairs(CACHE) do
			if type(obj) == "table" then
				if obj.filename == filename then
					ttf.unload(obj.id)
				end
			end
		end
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
		return obj.key
	end
end

local function fetch_name(nametable, name_)
	local name = string.lower(name_)
	for _, obj in ipairs(font.namelist) do
		local key = matching(obj, name)
		if key then
			local fontobj = CACHE[key]
			if not fontobj then
				-- make index
				local id = alloc_fontid()
				fontobj = {
					filename = obj.filename,
					index = obj.index,
					id = id,
				}
				CACHE[id] = key
				CACHE[key] = fontobj
			end

			local id = fontobj.id
			nametable[name_] = id
			return id
		end
	end
end

setmetatable(ttf.nametable, { __index = fetch_name })

function font.name(name)
	return ttf.nametable[name]
end

local function fetch_id(idtable, id)
	local key = assert(CACHE[id])
	local obj = CACHE[key]
	local c = CACHE[obj.filename]
	if c == nil then
		c = font.loader(obj.filename)
		CACHE[obj.filename] = c
	end
	return ttf.update(id, c, obj.index)
end

setmetatable(ttf.idtable, { __index = fetch_id })

function font.info(id)
	return ttf.idtable[id]
end

return font
