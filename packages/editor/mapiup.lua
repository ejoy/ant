local keymap = (import_package "ant.inputmgr").keymap

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

local function translate_status(status)
	local t = {}
	for i = 1, #status do	
		local n = status:sub(i, i)
		local v = status_map[n]
		if v then
			t[v] = true
		end
	end
	return t
end

local pressnames = {
	[0] = false,
	[1] = true,
}

local buttonnames = { 
	['1'] = "LEFT",
	['2'] = "MIDDLE",
	['3'] = "RIGHT",
	['4'] = "BUTTON4",
	['5'] = "BUTTON5"
}

local iupcodemap = {}
for k, v in pairs(iup) do
	if  type(v) == "number" and 
		type(k) == "string" then 
		local iup_name = k:match("K_([%w_%d]+)")
		if iup_name then
			iupcodemap[v] = iup_name
		end
	end
end

local iup_to_keymap = {
	LCTRL = "LCONTROL",
	RCTRL = "RCONTROL",
}

local keymapcache = {}
local function translate_key(iupkey)
	if keymapcache[iupkey] then
		return keymapcache[iupkey]
	end

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
		end		

		return ''
	end

	local name = iup.isXkey(basekey) and get_keyname(basekey) or string.char(basekey)	
	keymapcache[iupkey] = name
	return name
end

return function (msgqueue, ctrl)	
	ctrl.button_cb = function(_, btn, press, x, y, status)
		msgqueue:push("mouse_click", buttonnames[string.char(btn)], pressnames[press], x, y, translate_status(status))
	end

	ctrl.motion_cb = function(_, x, y, status)
		msgqueue:push("mouse_move", x, y, translate_status(status))
	end

	ctrl.wheel_cb = function(_, delta, x, y, status)
		-- not use status right now
		msgqueue:push("mouse_wheel", x, y, delta)
	end

	ctrl.keypress_cb = function(_, key, press)
		local t = {}
		if iup.isAltXkey(key) then
			t["ALT"] = true
		end

		if iup.isCtrlXkey(key) then
			t["CTRL"] = true
		end

		if iup.isSysXkey(key) then
			t["SYS"] = true
		end

		if iup.isShiftXkey(key) then
			t["SHIFT"] = true
		end
		msgqueue:push("keyboard", translate_key(key), pressnames[press], t)
	end
end