local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local class     = require "common.class"

local SumHeap = class("ScrollList.SumHeap")
function SumHeap:_init()
    self.container = {{}}
    self.top = 1
    self.raw_container = self.container[1]
end

function SumHeap:get_size()
    return #self.raw_container
end

function SumHeap:add_item(value)
    assert(type(value)=="number","value must be number,got "..type(value))
    assert(value>=0)
    table.insert(self.raw_container,value)
    local index = #self.raw_container
    self:_update_tree_from(index)
    return index
end

function SumHeap:_update_tree_from(index)
    local cur_size = #self.raw_container
    local cur_index = index
    local level = 1
    local cur_con = self.container[1]
    while cur_size > 1 do
    
        cur_index = (cur_index + 1)//2
        local right_child = cur_index * 2
        local left_child = right_child - 1
        cur_size = (cur_size + 1)//2
        level = level +1
        self.container[level] = self.container[level] or {}
        local parent_con = self.container[level]
        parent_con[cur_index] = (cur_con[left_child] or 0) + (cur_con[right_child] or 0)
        cur_con = parent_con
    end
    self.top = level
end

function SumHeap:get_item(index)
    return self.raw_container[index]
end

function SumHeap:update_item(index,value)
    assert( self.raw_container[index],"Index not exist:",index)
    assert(type(value)=="number","value must be number,got "..type(value))
    assert(value>=0)
    if self.raw_container[index] ~= value then
        self.raw_container[index] = value
        self:_update_tree_from(index)
    end
end

function SumHeap:get_index_range(index)
    local my_value = self.raw_container[index]
    assert(my_value)
    local cur_level = 1
    local cur_index = index
    local sum = 0
    local container = self.container
    while cur_level < self.top do
        if cur_index == 1 then
            return sum,sum+my_value
        else
            local is_right = cur_index%2 == 0
            if is_right then
                sum = sum + container[cur_level][cur_index-1]
            end
            cur_level = cur_level + 1
            cur_index = (cur_index+1)//2
        end
    end
    return sum,sum+my_value

end

function SumHeap:locat_item_by_range(startv,stopv)
    local start_index = self:local_item_by_value(startv)
    local end_index = self:local_item_by_value(stopv)
    return start_index,end_index
end

--return index
--return nil,0 or 1, 0:value <0,1:value out of range
function SumHeap:local_item_by_value(value)
    if #self.raw_container == 0 then
        return nil,1
    end
    if value < 0 then
        return nil,0
    end
    return self:_local_item_by_value(value,self.top,1)
end

function SumHeap:_local_item_by_value(value,level,index)
    local cur_value = self.container[level][index]
    if value > cur_value then
        assert(level == self.top)
        return nil,1
    end
    if value == 0 then
        return index
    end
    if level > 1 then
        local left_child = index * 2 - 1
        -- log("level+1:",level-1,left_child,self.container[level+1])
        local left_value = self.container[level-1][left_child]
        if value > left_value then
            return self:_local_item_by_value(value - left_value,level-1,left_child+1)
        else
            return self:_local_item_by_value(value,level-1,left_child)
        end
    else
        return index
    end
end


function SumHeap:get_last_item_range()
    local last_index = self:get_size()
    if last_index <= 0 then
        return 0,0,0
    else
        local start_v,end_v = self:get_index_range(last_index)
        return last_index,start_v,end_v
    end
end

--[[
@test
function SumHeap:log()
    log(">----------------------")
    for i,v in ipairs(self.container) do
        log(i,table.concat(v,","))
    end
    log("<----------------------")
end

local sumheap = SumHeap.new()
for i = 1,10 do
    sumheap:add_item(i)
end
sumheap:log()
log("test get_index_range")
for i = 1,10 do
    log(i,sumheap:get_index_range(i))
end
log("test local item index")
for i = -1,60 do
    local index = sumheap:local_item_by_value(i)
    if index then
        log(i,sumheap:local_item_by_value(i),sumheap:get_index_range(index))
    end
end
]]

local class     = require "common.class"

local ScrollList = class("ScrollList")

function ScrollList:_init()
    self.item_func = nil
    self.item_count = 0
    self.sumheap = nil
    self.last_scroll_y = 0
end

function ScrollList:set_data_func(func)
    self.item_func = func
    self.sumheap = SumHeap.new()    
end

function ScrollList:get_size()
    return self.item_count
end

function ScrollList:remove_all()
    self.sumheap = SumHeap.new()
    self.item_count = 0
    self.last_scroll_y = 0
end

function ScrollList:add_item_num(num)
    self.item_count = self.item_count + num
end

function ScrollList:update()
    
    local scrollY = windows.GetScrollY()
    local has_scroll_by_user = scrollY<self.last_scroll_y 
    local scroll_change = scrollY~=self.last_scroll_y 
    self.last_scroll_y = scrollY
    local sizeX,sizeY = windows.GetContentRegionAvail()
    local scrollEndY = scrollY + sizeY
    local heap = self.sumheap
    local index,typ = heap:local_item_by_value(scrollY)
    local last_render_index = nil
    local item_not_collected = self.item_count - heap:get_size()
    if not index then
        assert(typ == 1)
        if item_not_collected > 0 then
            --todo
            local last_heap_index,sv,ev = heap:get_last_item_range()
            local cur_index = last_heap_index + 1
            cursor.SetCursorPos(nil,ev)
            while cur_index <= self.item_count do
                self:_update_item(cur_index)
                local _,curY = cursor.GetCursorPos()
                last_render_index = cur_index
                if curY > scrollEndY then
                    break
                end
                cur_index = cur_index +1
            end
        --else nothing to render
            --
        end
    else
        local sv,ev = heap:get_index_range(index)
        local cur_index = index
        cursor.SetCursorPos(nil,sv)
        while cur_index <= self.item_count do
            self:_update_item(cur_index)
            local _,curY = cursor.GetCursorPos()
            last_render_index = cur_index
            if curY > scrollEndY then
                break
            end
            cur_index = cur_index +1
        end
    end
    item_not_collected = self.item_count - heap:get_size()
    local last_heap_index,sv,ev = heap:get_last_item_range()
    if item_not_collected <= 0 then
        cursor.SetCursorPos(nil,ev)
        if self.flag_to_last then
            windows.SetScrollY(ev)
            self.flag_to_last = false
        end
    else
        if last_heap_index >0 then
            ------optimize can be delete------------
            local try_num = math.floor(item_not_collected/30+0.5)
            try_num = math.min(try_num,10000 )
            local cur_index = last_heap_index + 1
            local count = 0
            cursor.SetCursorPos(nil,ev)
            while cur_index <= self.item_count and count<try_num do
                self:_update_item(cur_index)
                cur_index = cur_index +1
                count = count + 1
            end
            local last_heap_index,sv,ev = heap:get_last_item_range()
            item_not_collected = item_not_collected - try_num
            ------optimize can be delete------------
            local item_height = ( ev / last_heap_index) * 0.5
            local rest_size_y = item_height * item_not_collected
            cursor.SetCursorPos(nil,ev+rest_size_y)
            if self.flag_to_last then
                windows.SetScrollY(ev)
            end
        --else do nothing
        end
    end
    return has_scroll_by_user,scrollY >= windows.GetScrollMaxY(),scroll_change
end
function ScrollList:_update_item(item_index)
    local curX,curY1 = cursor.GetCursorPos()
    self.item_func(item_index,curX,curY1)
    local _,curY2 = cursor.GetCursorPos()
    local size = curY2 - curY1
    if self.sumheap:get_item(item_index) then
        self.sumheap:update_item(item_index,size)
    else
        self.sumheap:add_item(size)
    end
end

function ScrollList:scroll_to_last()
    self.flag_to_last = true
end

return ScrollList
