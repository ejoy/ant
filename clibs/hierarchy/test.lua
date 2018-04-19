local hierarchy = require "hierarchy"

local root = hierarchy.new()

root[1] = { name = "child" }

print(root[1].name)

local child = root[1]
child.name = "foobar"

print(child.name)

print(root[1].name)
local old = root[1]

root[2] = { name = "child2" }

local new = root[2]

root[1] = nil

print("root children num : ", #root)

for i, v in ipairs(root) do
	print("===>", i,v.name)
end

print(new.name)
print(old)	-- Invalid node

-- will rasie an error
--print(old.name)	-- Invalid node

--child[1] = { name = "child_1"}

child = root[1]

local child_1 = child[1]
assert(child_1 == nil)
child[1] = {name = "child_1"}

child_1 = child[1]
print(child_1.name)

child[2] = {name = "child_2"}
child_1[1] = {name = "child_1_1"}


local function print_tree(tr, offset_pr)
    local num = #tr
    if num == 0 then
        return 
    end

    for i=1, num do
        local child = assert(tr[i])        
        local child_num = #child

        print(offset_pr .. child.name)

        if child_num ~= 0 then            
            print_tree(child, offset_pr .. "\t")
        end
    end    
end

print('-------------------------------')
print_tree(root, "")
