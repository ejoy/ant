#pragma once

#include <map>
#include <string_view>

#include "embed/bootstrap.h"
#include "embed/debugger.h"
#include "embed/init_thread.h"
#include "embed/io.h"
#include "embed/vfs.h"

std::map<std::string_view, std::string_view> firmware = {
    { "bootstrap.lua", embed_bootstrap },
    { "debugger.lua", embed_debugger },
    { "init_thread.lua", embed_init_thread },
    { "io.lua", embed_io },
    { "vfs.lua", embed_vfs },
};
