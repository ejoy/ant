--luacheck: globals iup
local keymap = require "inputmgr.keymap"

local iupcodemap = {}
for k, v in pairs(iup) do
	if  type(v) == "number" and 
		type(k) == "string" then 
		local iup_name = k:match("K_([%w_%d]+)")
		if iup_name then
			iupcodemap[v] = iupcodemap
		end
	end
end

local iup_to_keymap = {
	LCTRL = "LCONTROL",
	RCTRL = "RCONTROL",
}

local iup_keymap_mt = {__mode = "kv"}
function iup_keymap_mt:__index(iupkey)
	local basekey = iup.XkeyBase(iupkey)

	local function get_keyname(basekey)
		local iupname = iupcodemap[basekey]
		if iupname then				
			local tname = iup_to_keymap[iupname]
			if tname then
				return tname
			end

			if keymap.code(iupname) then
				return iupname
			end
				
			return ''
		end		
	end

	local name = iup.isXkey(basekey) and get_keyname(basekey) or string.char(basekey)
	self[iupkey] = name
	return name
end
local iup_keymap = setmetatable({}, iup_keymap_mt)

local iup_status_mt = { __mode = "kv" }
local iup_status = setmetatable({}, iup_status_mt)

local status_map = {
	["1"] = "LEFT",
	["2"] = "MIDDLE",
	["3"] = "RIGHT",
	["4"] = "BUTTON4",
	["5"] = "BUTTON5",
	A = "ALT",
	C = "CTRL",
	Y = "SYS",
	S = "SHIFT",
	D = "DOUBLE",
}

local status_meta = { __tostring = function(self) return self.name end }

function iup_status_mt:__index(status)
	local s = setmetatable({}, status_meta)
	local str = {}
	for i = 1, #status do		
		local v = status_map[status:sub(i,i)]
		if v then
			s[v] = true
			table.insert(str, v)
		end
	end
	s.name = table.concat(str, "+")
	self[status] = s	
	return s
end

return {
	BUTTON = {
		[iup.BUTTON1] = "LEFT",
		[iup.BUTTON2] = "MIDDLE",
		[iup.BUTTON3] = "RIGHT",
		[iup.BUTTON4] = "BUTTON4",
		[iup.BUTTON5] = "BUTTON5",
	},
	PRESSED = {
		[1] = true,
		[0] = false,
	},
	STATUS = iup_status,
	KEY = iup_keymap,
	button = "BUTTON,PRESSED,_,_,STATUS",	-- button, pressed, x,y, status
	motion = "_,_,STATUS", -- x,y,status
	keypress = "KEY,PRESSED,STATUS",	-- keycode, pressed, status
	resize = "_,_",	-- width, height
	wheel = "_,_,_,STATUS",-- delta,x,y,status
}
