local protocol = import_package "ant.debugger".protocol
local fs = require "filesystem.local"
local statSend = {}
local statRecv = {}

local function fixPath(repo, path)
    return fs.absolute(repo:realpath(path)):string()
end

local function fixSourcePath(repo, source)
    if not source or not source.path then
        return
    end
    source.path = fixPath(repo, source.path)
end

local function convertPaths(repo, msg)
    if msg.type == "event" then
        if msg.event == "output" then
            fixSourcePath(repo, msg.body.source)
        elseif msg.event == "loadedSource" then
            fixSourcePath(repo, msg.body.source)
        elseif msg.event == "breakpoint" then
            fixSourcePath(repo, msg.body.breakpoint.source)
        end
    elseif msg.type == "response" then
        if msg.success then
            if msg.command == "stackTrace" then
                for _, frame in ipairs(msg.body.stackFrames) do
                    fixSourcePath(repo, frame.source)
                end
            elseif msg.command == "loadedSources" then
                for _, source in ipairs(msg.body.sources) do
                    fixSourcePath(repo, source)
                end
            elseif msg.command == "scopes" then
                for _, scope in ipairs(msg.body.scopes) do
                    fixSourcePath(repo, scope.source)
                end
            elseif msg.command == "setFunctionBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    fixSourcePath(repo, bp.source)
                end
            elseif msg.command == "setBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    fixSourcePath(repo, bp.source)
                end
            end
        end
    end
end

local function convertSend(repo, data)
    local msg = protocol.recv(data, statSend)
    convertPaths(repo, msg)
    return protocol.send(msg, statSend)
end

local function convertLaunch(msg)
    if msg.type ~= "request" then
        return
    end
    if msg.command ~= "launch" and msg.command ~= "attach" then
        return
    end
    msg.arguments.sourceFormat = "string"
    if msg.arguments.skipFiles then
        table.insert(msg.arguments.skipFiles, "/pkg/ant.debugger/*")
    else
        msg.arguments.skipFiles = {"/pkg/ant.debugger/*"}
    end
end

local function convertRecv(data)
    local msg = protocol.recv(data, statRecv)
    if msg then
        convertLaunch(msg)
        return protocol.send(msg, statRecv)
    end
end

return {
    convertSend = convertSend,
    convertRecv = convertRecv,
}
