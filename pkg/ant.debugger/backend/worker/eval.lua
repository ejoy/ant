local rdebug = require 'luadebug.visitor'
local luaver = require 'backend.worker.luaver'

local readfile = package.readfile
if not readfile then
    function readfile(filename)
        local fullpath = assert(package.searchpath(filename, package.path))
        local f = assert(io.open(fullpath))
        local str = f:read 'a'
        f:close()
        return str
    end
end

local eval_readwrite = assert(rdebug.load(readfile 'backend.worker.eval.readwrite'))
local eval_readonly  = assert(rdebug.load(readfile 'backend.worker.eval.readonly'))
local eval_verify    = assert(rdebug.load(readfile 'backend.worker.eval.verify'))

local m              = {}

function m.readwrite(expression, frameId)
    return rdebug.watch(eval_readwrite, expression, frameId)
end

function m.readonly(expression, frameId)
    return rdebug.watch(eval_readonly, expression, frameId)
end

function m.eval(expression, level, symbol)
    return rdebug.eval(eval_readonly, expression, level, symbol)
end

function m.verify(expression)
    return rdebug.eval(eval_verify, expression, 0)
end

local function generate(name, init)
    m[name] = function(...)
        local f = init()
        m[name] = f
        return f(...)
    end
end

generate("ffi_reflect", function ()
    if not luaver.isjit then
        return
    end
    local handler = assert(rdebug.load(readfile "backend.worker.eval.ffi_reflect"))
    local ok, fn = rdebug.watch(handler)
    if not ok then
        return
    end
    require 'backend.event'.on('terminated', function ()
        rdebug.eval(fn, "clean")
    end)
    return function (name, ...)
        local method = (name == "member" or name == "annotated_member") and "watch" or "eval"
        local res = table.pack(rdebug[method](fn, name, ...))
        if not res[1] then
            return
        end
        return table.unpack(res, 2)
    end
end)

return m
