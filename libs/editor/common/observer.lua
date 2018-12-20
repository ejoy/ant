local observers = {}; observers.__index = observers

function observers:add(ob)
	table.insert(self, ob)
end

function observers:notify(...)
	for _, ob in ipairs(self) do
		ob(...)
	end
end

function observers.new()
	return setmetatable({}, observers)
end

return observers