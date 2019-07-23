----------------test--------------------
--[[
--testlocal function get_hash(data)
    return data.msg
end
local linkList = LogLinkList.new(get_hash)
linkList:add_data({msg=32424})
linkList:add_data({msg=23434})
linkList:add_data({msg=32424})
print(linkList.item_count)
local item = linkList:get_item_by_index(1)
print(item.datas[1].msg)
print(linkList:get_item_by_index(2).datas[1].msg)

local target = linkList.head
while target do
    local t = {}
    table.insert(t,tostring(linkList:get_last_data_from_item(target).msg))
    if target.prev then
        table.insert(t,string.format("prev:%s",tostring(linkList:get_last_data_from_item(target.prev).msg)))
    end
    if target.next then
        table.insert(t,string.format("next:%s",tostring(linkList:get_last_data_from_item(target.next).msg)))
    end
    print(table.concat( t ,"\t"))
    target = target.next
end   
]]--
----------------------------------------
local LogLinkList = {}
LogLinkList.__index = LogLinkList

function LogLinkList.new(...)
    local t = setmetatable({},LogLinkList)
    t:_init(...)
    return t
end

function LogLinkList:_init(hash_func)
    self.hash_func = hash_func
    self.head = nil
    self.tail = nil
    self.item_count = 0
    self.hash_tbl = {}
    self.last_index_cache = nil
end

function LogLinkList:_get_data_hash(data)
    if self.hash_func then
        return self.hash_func(data)
    else
        return data
    end
end

function LogLinkList:add_data(data)
    assert(data)
    local hash = self:_get_data_hash(data)
    assert(hash)
    local item = self:get_item_by_hash(hash)
    if item then
        --add data to item
        --_move_item_to_end
        self:_add_data_to_item(item,data)
        self:_move_item_to_end(item)
        return false
    else
        local item = self:_create_item(data,hash)
        self:_add_item_to_end(item)
        return true
    end
end

function LogLinkList:_create_item(data,hash)
    local item = {
        datas = {data},
        hash = hash,
        prev = nil,
        next = nil,
    }
    self.hash_tbl[hash] = item
    return item
end

function LogLinkList:_add_item_to_end(item)
    if self.item_count == 0 then
        self.head =  item
        self.tail = item
    else
        self.tail.next = item
        item.prev = self.tail
        item.next = nil
        self.tail = item
    end
    self.item_count = self.item_count + 1
end


function LogLinkList:_add_data_to_item(item,data)
    table.insert(item.datas,data)
end


function LogLinkList:_move_item_to_end(item)
    assert(self.item_count >= 1)
    if self.tail == item then
        return
    end
    local prev = item.prev
    if prev then
        prev.next = item.next
    else -- no prev,item is head
        self.head = item.next
    end
    local nxt = item.next
    if nxt then
        nxt.prev = prev
    end
    ---------------
    self.tail.next =item
    item.prev = self.tail
    self.tail = item
    item.next = nil
end

function LogLinkList:get_item_by_hash(hash)
    return self.hash_tbl[hash]
end

function LogLinkList:get_item_by_index(index)
    assert(index<=self.item_count)
    local last_index = self.last_index_cache and self.last_index_cache[1]
    local function get_min_dist(index)
        local from_head = math.abs(index - 1)
        local from_tail = math.abs(self.item_count - 1)
        if from_head < from_tail then
            return 1,from_head
        else
            return 2,from_tail
        end
    end
    local function get_index_from_head_or_tail(index,t)
        if t == 1 then
            return self:_get_index_from_head(index)
        else
            return self:_get_index_from_tail(index)
        end
    end
    local result = nil
    if last_index then
        local last_index_dist = math.abs(index-last_index_dist)
        local t,dist = get_min_dist(index)
        if last_index_dist< dist then
            result = self:_get_index_from_cache(index)
        else
            result = get_index_from_head_or_tail(index,t)
        end
    else
        local t,dist = get_min_dist(index)
        result = get_index_from_head_or_tail(index,t)
    end
    return result
end

function LogLinkList:_get_index_from_cache(index)
    local target = self.last_index_cache[2]
    local from_index = self.last_index_cache[1]
    if index > from_index then
        for i = from_index+1,index do
            target = target.next
        end
    else
        for i = from_index-1,index,-1 do
            target = target.prev
        end
    end
    return target
end

function LogLinkList:_get_index_from_head(index)
    local target = self.head
    for i = 2,index do
        target = target.next
    end
    return target
end

function LogLinkList:_get_index_from_tail(index)
    local target = self.tail
    for i = self.item_count-1,index,-1 do
        target = target.prev
    end
    return target
end

function LogLinkList:get_item_last_data(index)
    local item = self:get_item_by_index(index)
    if item then
        return self:get_data_from_item(item)
    end
end

function LogLinkList:get_last_data_from_item(item)
    local datas = item.datas
    return datas[#datas]
end

function LogLinkList:clear()
    self.head = nil
    self.tail = nil
    self.item_count = 0
    self.hash_tbl = {}
    self.last_index_cache = nil
end

return LogLinkList