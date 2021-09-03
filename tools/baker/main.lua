local default_baker = "path_tracer"
package.path = "engine/?.lua"
require "bootstrap"
if default_baker == "path_tracer" then
    import_package "ant.tool.baker"
else
    import_package "ant.window".start "ant.tool.baker"
end