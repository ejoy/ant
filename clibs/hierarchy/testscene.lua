local scene = require "hierarchy.scene"

local q = scene.queue()
local _, index = debug.getupvalue(q.mount, 1)
local function print_q(expect)
	local tmp = {}
	for i, v in ipairs(q) do
		if v then
			local idx = assert(index[v], v .. " has no index")
			local position = idx >> 32
			local parent = idx & 0xffffffff
			if i~=position then
				error(string.format("%s : Invalid position %d(parent %d)",table.concat(tmp, " "), position,v))
			end
			table.insert(tmp, v .. "^" .. parent)
		else
			table.insert(tmp, ".")
		end
	end
	local result = table.concat(tmp, " ")
	print(result)
	assert(result == expect, expect)
end

-- A:1 B:2 C:3 D:4 E:5 F:6
--               A   B
--              /|   |
--             C D   E
--                   |
--                   F

local action = {
	{ 1, 0 },
	{ 3, 1 },
	{ 4, 1 },
	{ 2, 0 },
	{ 5, 2 },
	{ 6, 2 },
}

for _, m in ipairs(action) do
	q:mount(m[1],m[2])
end

print_q "1^0 3^1 4^1 2^0 5^2 6^2"

q:mount(1, 5)	-- A^E

--                   B
--                   |
--                   E
--                  /|
--                 A F
--                /|
--               C D

print_q "2^0 5^2 1^5 3^1 4^1 6^2"
q:mount(1)	-- remove A
print_q "2^0 5^2 . 3^1 4^1 6^2"
q:mount(6,1)
print_q "2^0 5^2 . 3^1 4^1 6^1"
local clear_objects = q:clear {}
print_q "2^0 5^2"
assert(clear_objects[1] == 1)
assert(clear_objects[2] == 3)
assert(clear_objects[3] == 4)
assert(clear_objects[4] == 6)


