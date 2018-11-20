-- local iup_keymap = {}

-- for k,v in pairs(iup) do
-- 	if type(k) == "string" and type(v) == "number" and k:sub(1,2) == "K_" then
-- 		iup_keymap[v] = k:sub(3)
-- 	end
-- end

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
	--KEY = iup_keymap,
	button = "BUTTON,PRESSED,_,_,STATUS",	-- button, pressed, x,y, status
	motion = "_,_,STATUS", -- x,y,status
	--keypress = "KEY,PRESSED",	-- keycode, pressed
	keypress = "_,_,_",	-- keycode, pressed
	resize = "_,_",	-- width, height
	wheel = "_,_,_,STATUS",-- delta,x,y,status
}
