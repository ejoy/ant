local function get_protocol()
    return dofile "script/common/protocol.lua"
end

return {
    get_protocol = get_protocol,
}
