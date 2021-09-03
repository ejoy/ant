local default_baker = "path_tracer"
local pkginfo = {
    name = "ant.tool.baker",
}

if default_baker == "GPU.radiosity" then
    pkginfo.ecs = {
        import = {
            "@ant.tool.baker",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.tool.baker|lightmap_baker_system",
        }
    }
elseif default_baker == "path_tracer" then
    pkginfo.entry = "CPU.path_tracer.bake"
end

return pkginfo