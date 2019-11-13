local protocol = import_package "ant.debugger".protocol
local fs = require "filesystem.local"
local statSend = {}
local statRecv = {}

local function pathToLocal(repo, path)
    return fs.absolute(repo:realpath(path)):string()
end

local function sourcePathToLocal(repo, source)
    if not source or not source.path then
        return
    end
    source.path = pathToLocal(repo, source.path)
end

local function convertSendPaths(repo, msg)
    if msg.type == "event" then
        if msg.event == "output" then
            sourcePathToLocal(repo, msg.body.source)
        elseif msg.event == "loadedSource" then
            sourcePathToLocal(repo, msg.body.source)
        elseif msg.event == "breakpoint" then
            sourcePathToLocal(repo, msg.body.breakpoint.source)
        end
    elseif msg.type == "response" then
        if msg.success then
            if msg.command == "stackTrace" then
                for _, frame in ipairs(msg.body.stackFrames) do
                    sourcePathToLocal(repo, frame.source)
                end
            elseif msg.command == "loadedSources" then
                for _, source in ipairs(msg.body.sources) do
                    sourcePathToLocal(repo, source)
                end
            elseif msg.command == "scopes" then
                for _, scope in ipairs(msg.body.scopes) do
                    sourcePathToLocal(repo, scope.source)
                end
            elseif msg.command == "setFunctionBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    sourcePathToLocal(repo, bp.source)
                end
            elseif msg.command == "setBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    sourcePathToLocal(repo, bp.source)
                end
            end
        end
    end
end

local function pathToDA(repo, path)
    local vp = repo:virtualpath(fs.relative(fs.path(path)))
    if vp then
        return '/' .. vp
    end
    return ''
end

local function sourcePathToDA(repo, source)
    if not source or not source.path then
        return
    end
    source.path = pathToDA(repo, source.path)
end

local function convertRecvPaths(repo, msg)
    if msg.type == "request" then
        if msg.command == "setBreakpoints" then
            sourcePathToDA(repo, msg.arguments.source)
        elseif msg.command == "breakpointLocations" then
            sourcePathToDA(repo, msg.arguments.source)
        elseif msg.command == "source" then
            sourcePathToDA(repo, msg.arguments.source)
        elseif msg.command == "gotoTargets" then
            sourcePathToDA(repo, msg.arguments.source)
        end
    end
end

local function convertSend(repo, data)
    local msg = protocol.recv(data, statSend)
    convertSendPaths(repo, msg)
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

local function convertRecv(repo, data)
    local msg = protocol.recv(data, statRecv)
    if msg then
        convertLaunch(msg)
        convertRecvPaths(repo, msg)
        return protocol.send(msg, statRecv)
    end
end

return {
    convertSend = convertSend,
    convertRecv = convertRecv,
}
