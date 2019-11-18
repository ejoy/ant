local lfs = require "filesystem.local"
local output = lfs.path "tools/antpack/.output"
lfs.remove_all(output)
lfs.create_directories(output)
lfs.create_directories(output / ".repo")
lfs.copy(lfs.path "runtime/windows/ant.exe",   output / "ant.exe",             true)
lfs.copy(lfs.path "clibs/libgcc_s_seh-1.dll",  output / "libgcc_s_seh-1.dll",  true)
lfs.copy(lfs.path "clibs/libwinpthread-1.dll", output / "libwinpthread-1.dll", true)
lfs.copy(lfs.path "clibs/libstdc++-6.dll",     output / "libstdc++-6.dll",     true)


local f = assert(lfs.open(output / ".repo" / "config", "wb"))
f:write "nettype = undef\n"
f:close()

local client = require "vfs_client"

client.initialize {
    repopath = output:string(),
    rootname = assert(arg[1], "Need repo name"),
    nettype = "connect",
    address = "127.0.0.1",
    port = 2018,
}

client.prefetch ".windows[ ]_direct3d11"
