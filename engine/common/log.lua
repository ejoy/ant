--------------------useage----------------------------------------
--[[
log(1,2,3) <=> log.info(1,2,3) ==> "[info]:1   2   3"
log.error(1,2,3) =>  "[error]:1   2   3"
log.print({color="#80ffffff",...},1,2,3) => "[#80ffffff]1   2   3"
]]


local log = {}
local levels = {"trace","info","warn","error","fatal"}

local gen_log = function(typ)
    return function(...)
        local cfg = {type=typ}
        log.print(cfg,...)
    end
end
local gen_log_a = function(typ)
    return function(...)
        local dump = dump_a({...})
        log[typ](dump)
    end
end

for i,v in ipairs(levels) do
    log[v] = gen_log(v)
    log[v.."_a"] = gen_log_a(v)
end

local function tconcat(...)
    local num = select("#",...)
    local args = {...}
    for i = 1,num do
        args[i] = tostring(args[i])
    end
    return table.concat(args,"\t")
end

local os_date = function(fmt,time)
    local ti, tf = math.modf(time)
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

local _default = function(cfg,msg,time)
    local prefix = nil
    if cfg.type then
        prefix = cfg.type
    elseif type(cfg.color) == "string" then
        prefix = log.default
    end
    local data = nil
    if prefix then
        data = ('[%s][%s] %s'):format(
            os_date('%Y-%m-%d %H:%M:%S:{ms}',time), 
            prefix:upper(), 
            msg)

    else
        data = ('[%s] %s'):format(
            os_date('%Y-%m-%d %H:%M:%S:{ms}',time), 
            msg)
    end
    print(data)
end

log._output = _default


-- cfg:{
--     color = {0.5,1,1,1} or "#80FFFFFF",
--     log_id = nil,--not use yet
--     type = "trace", --( color or type ) need one
-- }
local origin_time = os.time() - os.clock()
log.print = function( cfg,... )
    local msg = tconcat(...)
    local now = origin_time + os.clock()
    log._output(cfg,msg,now)
end

log.set_output = function(func)
    log._output = func or _default
end

log = setmetatable(log,{  
    __call = function(self,...)
        self.info(...)
    end
})

return log
