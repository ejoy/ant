local ltask = require "ltask"

local M = {}

local ServiceGame = ltask.queryservice "ant.window|world"

local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep

local function infostring(root)
	if type(root) ~= "table" then
		return tostring(root)
	end
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	return _dump(root, "","")
end

function M.get(path, q)
	local info = ltask.call(ServiceGame, "info", path, q)
	return 200, infostring(info)
end

return M