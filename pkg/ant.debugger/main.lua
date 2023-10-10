local function get_protocol()
    return dofile "/pkg/ant.debugger/script/common/protocol.lua"
end

return {
    get_protocol = get_protocol,
}
