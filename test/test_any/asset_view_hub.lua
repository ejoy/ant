local asset_view_hub = {}
local fs_hierarchy_hub = require "fs_hierarchy_hub"
local iupcontrols = import_package "ant.iupcontrols"
local hub = iupcontrols.common.hub

function asset_view_hub.subscribe(ins)
    hub.subscibe(fs_hierarchy_hub.CH_SELECT_FILES,
                ins.set_select_files,
                ins)
end


return asset_view_hub
