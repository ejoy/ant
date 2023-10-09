local protocol = import_package "ant.debugger".get_protocol()
local statSend = {}
local statRecv = {}

local function sourcePathToLocal(convert, source)
    if not source or not source.path then
        return
    end
    source.path = convert(source.path)
end

local function convertSendPaths(convert, msg)
    if msg.type == "event" then
        if msg.event == "output" then
            sourcePathToLocal(convert, msg.body.source)
        elseif msg.event == "loadedSource" then
            sourcePathToLocal(convert, msg.body.source)
        elseif msg.event == "breakpoint" then
            sourcePathToLocal(convert, msg.body.breakpoint.source)
        end
    elseif msg.type == "response" then
        if msg.success then
            if msg.command == "stackTrace" then
                for _, frame in ipairs(msg.body.stackFrames) do
                    sourcePathToLocal(convert, frame.source)
                end
            elseif msg.command == "loadedSources" then
                for _, source in ipairs(msg.body.sources) do
                    sourcePathToLocal(convert, source)
                end
            elseif msg.command == "scopes" then
                for _, scope in ipairs(msg.body.scopes) do
                    sourcePathToLocal(convert, scope.source)
                end
            elseif msg.command == "setFunctionBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    sourcePathToLocal(convert, bp.source)
                end
            elseif msg.command == "setBreakpoints" then
                for _, bp in ipairs(msg.body.breakpoints) do
                    sourcePathToLocal(convert, bp.source)
                end
            end
        end
    end
end

local function convertSend(convert, data)
    local msg = protocol.recv(data, statSend)
    convertSendPaths(convert, msg)
    return protocol.send(msg, statSend)
end

local function sourcePathToDA(convert, source)
    if not source or not source.path then
        return
    end
    source.path = convert(source.path)
end

local function convertRecvPaths(convert, msg)
    if msg.type == "request" then
        if msg.command == "setBreakpoints" then
            sourcePathToDA(convert, msg.arguments.source)
        elseif msg.command == "breakpointLocations" then
            sourcePathToDA(convert, msg.arguments.source)
        elseif msg.command == "source" then
            sourcePathToDA(convert, msg.arguments.source)
        elseif msg.command == "gotoTargets" then
            sourcePathToDA(convert, msg.arguments.source)
        end
    end
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

local function convertRecv(convert, data)
    local msg = protocol.recv(data, statRecv)
    if msg then
        convertLaunch(msg)
        convertRecvPaths(convert, msg)
        return protocol.send(msg, statRecv)
    end
end

return {
    convertSend = convertSend,
    convertRecv = convertRecv,
}
