local class     = require "common.class"
local AutoOffsetPlotLines   = class("AutoOffsetPlotLines")
local steps = nil
local default_func = function(values,cache)
    if  steps == nil then
        steps = {-10000000000}
        local cur = steps[1]
        while cur < -10 do
            cur = cur * 0.5
            table.insert(steps,cur)
        end 
        table.insert(steps,0)
        table.insert(steps,10)
        cur = 10
        while cur < 10000000000 do
            cur = cur * 2
            table.insert(steps,cur)
        end 
    end
    local min_v = values[1] or 0
    for i,v in ipairs(values) do
        min_v = math.min(v,min_v)
    end
    local last_index = cache or 1
    local index = last_index
    if steps[last_index] <= min_v then
        while steps[last_index] <= min_v and last_index < #steps do
            last_index =last_index + 1
        end
        index = last_index - 1
    else
        while steps[last_index] > min_v do
            last_index = last_index -1
        end
        index = last_index
    end
    return steps[index],index


end

function AutoOffsetPlotLines:_init(max_size)
    self.max_size = max_size or 100
    self.queue = {}
    self.calc_offset = default_func
end

function AutoOffsetPlotLines:set_offset_calc_func(func)
    self.calc_offset = func
end

function AutoOffsetPlotLines:add_value(val)
    local queue = self.queue
    table.insert(self.queue,val)
    if #queue > self.max_size then
        table.remove(queue,1)
    end
    self.offset,self.fun_cache = self.calc_offset(queue,self.fun_cache)
end

function AutoOffsetPlotLines:update()
    
end

function AutoOffsetPlotLines:clear()
    self.queue = {}
end
