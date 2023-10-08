return function(root, pid, name, mode)
    return io.open(tostring(root).."/tmp/ipc_"..pid.."_"..name, mode)
end
