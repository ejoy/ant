local ltask = require "ltask"
local bundle = require "bundle"
local vfs = require "vfs"
local glob = require "glob"

local S = {}
local File = {}
local Bundle = {}

local STATUS_NULL <const> = 1
local STATUS_WAIT <const> = 2
local STATUS_OK <const> = 3

local function read_bundle(path)
    local f <close> = io.open(path, "rb")
    if not f then
        return
    end
    local patterns = {}
    local attributes = {}
    for line in f:lines() do
        local type, pattern = line:match "([as])[%s]+(%S+)"
        if type then
            patterns[#patterns+1] = pattern
            attributes[#attributes+1] = type
        end
    end
    return patterns, attributes
end

local function open_bundle(path)
    local realpath = vfs.realpath(path)
    if not realpath then
        return
    end
    local patterns, attributes = read_bundle(realpath)
    return glob("/", patterns, attributes)
end

local function create_bundle(path)
    local res = open_bundle(path)
    if not res then
        return
    end
    local request = ltask.request()
    local SELF = ltask.self()
    local obj, view = bundle.create_bundle(res.files)
    for i, file in ipairs(res.files) do
        local attr = res.attributes[i]
        local v = File[file]
        if v then
            table.insert(v.bundle, path)
            if v.attribute == "a" and attr == "s" then
                request:add { SELF, "open_file", file }
            end
        else
            File[file] = {
                status = STATUS_NULL,
                attribute = attr,
                bundle = {path}
            }
            if attr == "s" then
                request:add { SELF, "open_file", file }
            end
        end
    end
    return obj, view, request
end

function S.open_bundle(path)
    local v = Bundle[path]
    if v == nil then
        v = {}
        Bundle[path] = v
        v.status = STATUS_WAIT
        local request
        v.obj, v.view, request = create_bundle(path)
        for req, resp in request:select() do
            if not resp then
                error(req.error)
            end
        end
        v.status = STATUS_OK
        ltask.multi_wakeup("[bundle]"..path)
    elseif v.status == STATUS_WAIT then
        ltask.multi_wait("[bundle]"..path)
    end
    return v.view
end

function S.close_bundle(path)
    local v = Bundle[path]
    if v == nil then
        error("bundle not opened")
    end
    --TODO
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
