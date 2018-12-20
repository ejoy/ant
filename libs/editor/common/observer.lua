local observers = {}; observers.__index = observers

function observers:find(name)
	for idx, ob in ipairs(self) do
		if ob.name == name then
			return idx
		end
	end
end

function observers:add(name, ob)
	assert(self:find(name) == nil)
	table.insert(self, {name, cb=ob})
end

function observers:remove(name)
	local idx = self:find(name)
	if idx then
		table.remove(self, idx)
	end
end

function observers:notify(...)
	for _, ob in ipairs(self) do
		ob.cb(...)
	end
end

function observers.new()
	return setmetatable({}, observers)
end

return observers