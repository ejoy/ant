local ltask = require "ltask"
local fs = require "filesystem.cpp"
local REPO = {}

local _origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(_origin + os.clock())
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

local function getlogindex(filename)
    local s = filename:match "runtime%-(%d+)%.log"
    if s then
        return tonumber(s)
    end
end

local function readfile(filename)
    local f <close> = assert(io.open(filename:string(), "rb"))
    return f:read "a"
end

local function writefile(filename, data)
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local function movelog(LOGDIR, idx)
    local TIMESTAMP = LOGDIR / (".timestamp-%d"):format(idx)
    local timestamp = readfile(TIMESTAMP)
    fs.create_directories(LOGDIR / 'backup')
    fs.rename(LOGDIR / ("runtime-%d.log"):format(idx), LOGDIR / 'backup' / (timestamp .. ".log"))
    fs.remove(TIMESTAMP)
end

local S = {}

function S.CREATE(repopath)
    local LOGDIR = fs.path(repopath) / ".log"
    local repo = REPO[repopath]
    if not repo then
        repo = {}
        REPO[repopath] = repo
    end
    local i = 1
    while repo[i] do
        i = i + 1
    end
    fs.create_directories(LOGDIR)
    for LOGFILE in LOGDIR:list_directory() do
        if fs.is_regular_file(LOGFILE) and LOGFILE:equal_extension ".log" then
            local index = getlogindex(LOGFILE:filename():string())
            if index and not repo[index] then
                movelog(LOGDIR, index)
            end
        end
    end
    repo[i] = true
    writefile(LOGDIR / (".timestamp-%d"):format(i), os_date('%Y_%m_%d_%H_%M_%S_{ms}'))
    return i, (LOGDIR / ("runtime-%d.log"):format(i)):string()
end

function S.CLOSE(repopath, index)
    local repo = REPO[repopath]
    if repo then
        local LOGDIR = fs.path(repopath) / ".log"
        movelog(LOGDIR, index)
        repo[index] = nil
    end
end

function S.QUIT()
    for repopath, repo in pairs(REPO) do
        local LOGDIR = fs.path(repopath) / ".log"
        for index in pairs(repo) do
            movelog(LOGDIR, index)
        end
    end
    REPO = {}
    ltask.quit()
end

return S
