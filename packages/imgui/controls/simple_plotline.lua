local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor

local class     = require "common.class"
local SimplePlotline   = class("SimplePlotline")
local steps = nil
-- local default_func = function(values,cache)
--     if  steps == nil then
--         steps = {-10000000000}
--         local cur = steps[1]
--         while cur < -10 do
--             cur = cur * 0.5
--             table.insert(steps,cur)
--         end 
--         table.insert(steps,0)
--         table.insert(steps,10)
--         cur = 10 
--         while cur < 10000000000 do
--             cur = cur * 2
--             table.insert(steps,cur)
--         end 
--     end
--     -------------
--     local min_v = values[1] or 0
--     for i,v in ipairs(values) do
--         min_v = math.min(v,min_v)
--     end
--     local last_index = cache[1] or 1
--     local index_min = last_index
--     if steps[last_index] <= min_v then
--         while steps[last_index] <= min_v and last_index < #steps do
--             last_index =last_index + 1
--         end
--         index_min = last_index - 1
--     else
--         while steps[last_index] > min_v do
--             last_index = last_index -1
--         end
--         index_min = last_index
--     end
--     ----
--     local max_v = values[1] or 0
--     for i,v in ipairs(values) do
--         max_v = math.min(v,max_v)
--     end
--     last_index = cache[2] or 1
--     local index_max = nil
--     if steps[last_index] >= max_v then
--         while steps[last_index] >= max_v and last_index < #steps do
--             last_index =last_index - 1
--         end
--         index_max = last_index + 1
--     else
--         while steps[last_index] < max_v do
--             last_index = last_index + 1
--         end
--         index_max = last_index
--     end
--     return {steps[index_min],steps[index_max]},{index_min,index_max}


-- end

function SimplePlotline:_init(title,max_size)
    self.max_size = max_size or 100
    self.queue = {}
    self.calc_offset = default_func
    self.offset = {nil,nil}
    self.fun_cache = {nil,nil}
    self.title = title
end

function SimplePlotline:set_offset_calc_func(func)
    self.calc_offset = func
end

function SimplePlotline:add_value(val)
    local queue = self.queue
    table.insert(self.queue,val)
    if #queue > self.max_size then
        table.remove(queue,1)
    end
    -- self.offset,self.fun_cache = self.calc_offset(queue,self.fun_cache)
end

function SimplePlotline:update()
    widget.PlotHistogram(self.title, self.queue)
end

function SimplePlotline:clear()
    self.queue = {}
    self.offset = {nil,nil}
    self.fun_cache = {nil,nil}
end

return SimplePlotline