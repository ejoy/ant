local class =  require "common.class"

local TimeStack = class("Common.TimeStack")

function TimeStack:_init()
    self.time_dic = {}
    self.run_stack = {}
    self.stack_size = 0
end

function TimeStack:Push(name_id)
    assert(name_id)
    local cur_size = self.stack_size
    local stack = self.run_stack
    if cur_size > 0 then
        if self.run_stack[cur_size].id == name_id then
            log.warn("Push same id twice:",name_id)
        end
    end
    local t = { id = name_id, ts = os.clock() }
    self.stack_size = cur_size + 1
    self.run_stack[cur_size + 1] = t
end

--name_id can't be nil,use to check stack top only
function TimeStack:Pop(name_id)
    local cur_size = self.stack_size
    local stack = self.run_stack
    assert(cur_size>0)
    local top = stack[cur_size]
    local top_id = top.id
    if name_id then
        assert( top_id == name_id )
    end
    self.stack_size = cur_size - 1
    local now = os.clock()
    self.time_dic[top_id] = self.time_dic[top_id] or 0
    self.time_dic[top_id] = self.time_dic[top_id] + now - top.ts
end

function TimeStack:get_time_dic(clear_flag)
    local time_dic = self.time_dic
    if clear_flag then
        self:clear()
    end
    return time_dic
end

--sort = "k" or "v" or nil
function TimeStack:get_time_list(sort,clear_flag)
    local dic = self:get_time_dic(clear_flag)
    local list = {}
    for k,v in pairs(dic) do
        table.insert(list,{k,v})
    end
    if sort == "k" then
        table.sort(list,
            function(a,b)
                return a[1]<b[1] 
            end
        )
    elseif sort == "v" then
        table.sort(list,
            function(a,b)
                return a[2]<b[2]
            end
        )
    end
    return list
end

function TimeStack:clear()
    self.time_dic = {}
end

return TimeStack

