local ecs = require "ecs"
local datalist = require "datalist"

local M = {}

local function get_keys(w, e)
	local keys = {}
	local n = 1
	for k in pairs(e) do
		if type(k) == "string" and k ~= "eid" then
			local t = w:type(k)
			if t ~= "lua" then
				-- ignore lua components
				keys[n] = k; n = n + 1
			end
		end
	end
	table.sort(keys)
	return keys
end

local function sort_keys(v)
	local keys = {}
	local t = 1
	for k in pairs(v) do
		keys[t] = k; t = t + 1
	end
	table.sort(keys)
	return keys
end

local function write_entity(w, f, e)
	local keys = get_keys(w, e)
	local output = { "---" }
	local n = 2
	output[n] = "eid : " .. e.eid ; n = n + 1
	for _, key in ipairs(keys) do
		local v = e[key]
		if type(v) == "table" then
			output[n] = key .. " :" ; n = n + 1
			for _, k in ipairs(sort_keys(v)) do
				output[n] = "\t" .. k .. " : " .. tostring(v[k]) ; n = n + 1
			end
		else
			output[n] = key .. " : " .. tostring(v) ; n = n + 1
		end
	end
	f:write(table.concat(output, "\n"))
	f:write "\n"
end

function M.export(w, filename)
	local f = assert(io.open(filename, "wb"))
	for e in w:select "eid" do
		w:readall(e)
		write_entity(w, f, e)
	end
	f:close()
end

function M.import(w, data)
	for _, e in ipairs(data) do
		local eid = e.eid
		e.eid = nil
		local allocid = w:new()
		while allocid < eid do
			w:remove(allocid)
			allocid = w:new()
		end
		assert(allocid == eid)
		w:import(eid, e)
	end
	w:update()
end

return M
