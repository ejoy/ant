local ltask = require "ltask"
local bundle = require "bundle"
local vfs = require "vfs"

local S = {}
local File = {}
local Bundle = {}

local STATUS_NULL <const> = 1
local STATUS_WAIT <const> = 2
local STATUS_OK <const> = 3

local function open_bundle(path)
    local realpath = vfs.realpath(path)
    if not realpath then
        return
    end
    local f <const> = io.open(realpath, "rb")
    if not f then
        return
    end
    local data = {}
    for line in f:lines() do
        data[#data+1] = line
    end
    return data
end

local function create_bundle(path)
    local data = open_bundle(path)
    if not data then
        return
    end
    local obj, view = bundle.create_bundle(data)
    for _, file in ipairs(data) do
        local v = File[file]
        if v then
            table.insert(v.bundle, path)
        else
            File[file] = {
                status = STATUS_NULL,
                bundle = {path}
            }
        end
    end
    return obj, view
end

function S.open_bundle(path)
    local v = Bundle[path]
    if v == nil then
        v = {}
        Bundle[path] = v
        v.status = STATUS_WAIT
        v.obj, v.view = create_bundle(path)
        v.status = STATUS_OK
        ltask.multi_wakeup("[bundle]"..path)
    elseif v.status == STATUS_WAIT then
        ltask.multi_wait("[bundle]"..path)
    end
    return v.view
end

function S.open_file(path)
    local v = File[path]
    if v == nil then
        error("bundle does not exist file: " ..path)
    end
    if v.status == STATUS_OK then
    elseif v.status == STATUS_NULL then
        v.status = STATUS_WAIT
        v.value = vfs.realpath(path)
        for _, b in ipairs(v.bundle) do
            Bundle[b].obj[path] = v.value
        end
        v.status = STATUS_OK
        ltask.multi_wakeup("[file]"..path)
    else -- v.status == STATUS_WAIT
        ltask.multi_wait("[file]"..path)
    end
    return v.value
end

return S
