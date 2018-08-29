local LUA_TNIL = 0
local LUA_TBOOLEAN = 1
local LUA_TNUMFLT = 3 | (0 << 4)
local LUA_TNUMINT = 3 | (1 << 4)
local LUA_TSHRSTR = 4 | (0 << 4)
local LUA_TLNGSTR = 4 | (0 << 4)

local unpack_buf = ''
local unpack_pos = 1
local function unpack_setpos(...)
    unpack_pos = select(-1, ...)
    return ...
end
local function unpack(fmt)
    return unpack_setpos(fmt:unpack(unpack_buf, unpack_pos))
end

local function LoadInt()
    return unpack 'i'
end

local function LoadByte()
    return unpack 'B'
end

local function LoadInteger()
    return unpack 'j'
end

local function LoadNumber()
    return unpack 'n'
end

local function LoadSize()
    return unpack 'T'
end

local function LoadCharN(n)
    return unpack('c' .. tostring(n))
end

local function LoadString()
    local size = LoadByte()
    if size == 0xFF then
        size = LoadSize()
    end
    if size == 0 then
        return nil
    end
    return LoadCharN(size-1)
end

local function CheckHeader()
    assert(LoadCharN(4) == '\x1bLua')
    assert(LoadByte() == 0x53)
    assert(LoadByte() == 0)
    assert(LoadCharN(6) == '\x19\x93\r\n\x1a\n')
    assert(LoadByte() == 4) -- int
    assert(LoadByte() == 8) -- size_t
    assert(LoadByte() == 4) -- Instruction
    assert(LoadByte() == 8) -- lua_Integer
    assert(LoadByte() == 8) -- lua_Number
    assert(LoadInteger() == 0x5678)
    assert(LoadNumber() == 370.5)
end

local function LoadCode(f)
    f.sizecode = LoadInt(S)
    f.code = {}
    for i = 1, f.sizecode do
        f.code[i] = LoadInt()
    end
end

local LoadFunction

local function LoadConstants(f)
    f.sizek = LoadInt()
    f.k = {}
    for i = 1, f.sizek do
        local t = LoadByte()
        if t == LUA_TNIL then
        elseif t == LUA_TBOOLEAN then
            f.k[i] = LoadByte()
        elseif t == LUA_TNUMFLT then
            f.k[i] = LoadNumber()
        elseif t == LUA_TNUMINT then
            f.k[i] = LoadInteger()
        elseif t == LUA_TSHRSTR then
            f.k[i] = LoadString()
        elseif t == LUA_TLNGSTR then
            f.k[i] = LoadString()
        else
            assert(false)
        end
    end
end

local function LoadUpvalues(f)
    f.sizeupvalues = LoadInt()
    f.upvalues = {}
    for i = 1, f.sizeupvalues do
        f.upvalues[i] = {}
        f.upvalues[i].instack = LoadByte()
        f.upvalues[i].idx = LoadByte()
    end
end

local function LoadProtos(f)
    f.sizep = LoadInt()
    f.p = {}
    for i = 1, f.sizep do
        f.p[i] = {}
        LoadFunction(f.p[i], f.source)
    end
end

local function LoadDebug(f)
    f.sizelineinfo = LoadInt()
    f.lineinfo = {}
    for i = 1, f.sizelineinfo do
        f.lineinfo[i] = LoadInt()
    end
    f.sizelocvars = LoadInt()
    f.locvars = {}
    for i = 1, f.sizelocvars do
        f.locvars[i] = {}
        f.locvars[i].varname = LoadString()
        f.locvars[i].startpc = LoadInt()
        f.locvars[i].endpc = LoadInt()
    end
    local n = LoadInt()
    for i = 1, n do
        f.upvalues[i].name = LoadString()
    end
end

function LoadFunction(f, psource)
    f.source = LoadString()
    if not f.source then
      f.source = psource
    end
    f.linedefined = LoadInt()
    f.lastlinedefined = LoadInt()
    f.numparams = LoadByte()
    f.is_vararg = LoadByte()
    f.maxstacksize = LoadByte()
    LoadCode(f)
    LoadConstants(f)
    LoadUpvalues(f)
    LoadProtos(f)
    LoadDebug(f)
    return f
end

local function undump(bytes)
    unpack_pos = 1
    unpack_buf = bytes
    local cl = {}
    CheckHeader()
    cl.nupvalues = LoadByte()
    cl.f = {}
    LoadFunction(cl.f, nil)
    assert(unpack_pos == #unpack_buf + 1)
    assert(cl.nupvalues == cl.f.sizeupvalues)
    return cl
end

return undump
