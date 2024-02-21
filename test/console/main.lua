package.path = "/engine/?.lua"
require "bootstrap"

-- See pkg/main/service/startup.lua
import_package "main".start(arg)
