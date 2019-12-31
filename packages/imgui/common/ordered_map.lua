class = require "common.class"

OrderedMap = class("common.OrderedMap")

local function default_cmp(a,b)
    return a == b
end

function OrderedMap:_init(cmpFun)
    self.cmpFun = cmpFun or default_cmp
    self.list = {}
    self.map = {}
end

function OrderedMap:insert(a)
    if self.map[a] then
        return false
    else
        self.map[a] = true
        table.insert(self.list,a)
    end
end

function OrderedMap:remove(a)
    if self.map[a] then
        self.map[a] = nil
        for i,v in ipairs(self.list) do
            if v == a then
                table.remove(self.list,i)
                break
            end
        end
        return true
    else
        return false
    end

end

function OrderedMap:append(list)
    for i,v in ipairs(list) do
        self:insert(v)
    end
end

function OrderedMap:removeAll()
    self.list = {}
    self.map = {}
end

function OrderedMap:has(a)
    return self.map[a]
end

function OrderedMap:get_list()
    return self.list
end

return OrderedMap
