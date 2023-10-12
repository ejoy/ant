local ecs = ...

local m = ecs.system "debug_system"

local dbg = debug.getregistry()["lua-debug"]
if not dbg then
    return
end

local vfs = require "vfs"
local lfs = require "bee.filesystem"
local LogDir = vfs.repopath
    and lfs.path(vfs.repopath()) / ".log"
    or lfs.current_path() / ".log"
lfs.create_directories(LogDir)

local world = ecs.world
local w = world.w

local evKeyboard = world:sub {"keyboard"}

function m:init()
    dbg:event("autoUpdate", false)
end

local function sortpairs(t, sortfunc)
    local sort = {}
    for k, v in pairs(t) do
        sort[#sort+1] = {k, v}
    end
    table.sort(sort, sortfunc)
    local n = 1
    return function ()
        local kv = sort[n]
        if kv == nil then
            return
        end
        n = n + 1
        return kv[1], kv[2]
    end
end

local function sortfunc(a, b)
    return #a[2] > #b[2]
end

local function writefile(filename, t)
    local map = {}
    for k, v in pairs(t) do
        local l = map[v]
        if l then
            l[#l+1] = k
        else
            map[v] = {k}
        end
    end
    local out = {}
    for k, v in sortpairs(map, sortfunc) do
        out[#out+1] = table.concat(v, ",")
        out[#out+1] = k
    end
    local f <close> = assert(io.open((LogDir / filename):string(), "wb"))
    f:write(table.concat(out, "\n"))
end

local snapshot = {}

local function RecordEntity()
    snapshot = {}
    for e in w:select "debug:in eid:in" do
        snapshot[e.eid] = e.debug
    end
end

local function DiffEntity()
    local diff_new = {}
    local diff_del = {}
    local newsnapshot = {}
    for e in w:select "debug:in eid:in" do
        local eid = e.eid
        local debug = e.debug
        if not snapshot[eid] then
            diff_new[eid] = debug
        else
            newsnapshot[eid] = true
        end
    end
    for eid, e in pairs(snapshot) do
        if not newsnapshot[eid] then
            diff_del[eid] = e
        end
    end
    writefile("./entity_new.txt", diff_new)
    writefile("./entity_del.txt", diff_del)
end

function m:end_frame()
    for _, what, press in evKeyboard:unpack() do
        if press == 1 then
            if what == "OEM_4" then
                RecordEntity()
            elseif what == "OEM_6" then
                DiffEntity()
            end
        end
    end
    dbg:event "update"
end
