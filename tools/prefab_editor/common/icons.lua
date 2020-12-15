local icon_path = {
    ["ICON_FILE"]           = "res/icon/File.png",
    ["ICON_FOLD"]           = "res/icon/Folder.png",
    ["ICON_LOCK"]           = "res/icon/Lock.png",
    ["ICON_UNLOCK"]         = "res/icon/Unlock.png",
    ["ICON_VISIBLE"]        = "res/icon/GuiVisibilityVisible.png",
    ["ICON_UNVISIBLE"]      = "res/icon/GuiVisibilityHidden.png",
    ["ICON_SELECT"]         = "res/icon/ToolSelect.png",
    ["ICON_MOVE"]           = "res/icon/ToolMove.png",
    ["ICON_SCALE"]          = "res/icon/ToolScale.png",
    ["ICON_ROTATE"]         = "res/icon/ToolRotate.png",
    ["ICON_SCRIPT"]         = "res/icon/Script.png",
    ["ICON_SHADER"]         = "res/icon/Shader.png",
    ["ICON_IMAGE"]          = "res/icon/Image.png",
    ["ICON_MESH"]           = "res/icon/Mesh.png",
    ["ICON_OBJECT"]         = "res/icon/Object.png",
    ["ICON_WORLD3D"]        = "res/icon/World3D.png",
    ["ICON_ANIMATION"]      = "res/icon/Animation.png",
    ["ICON_SKELETON3D"]     = "res/icon/Skeleton3D.png",
    ["ICON_CAMERA3D"]       = "res/icon/Camera3D.png",
    ["ICON_CAPSULEMESH"]    = "res/icon/CapsuleMesh.png",
    ["ICON_CUBEMESH"]       = "res/icon/CubeMesh.png",
    ["ICON_CYLINDERMESH"]   = "res/icon/CylinderMesh.png",
    ["ICON_SPHEREMESH"]     = "res/icon/SphereMesh.png",
    ["ICON_FAVORITES"]      = "res/icon/Favorites.png",
    ["ICON_MESHLIBRARY"]    = "res/icon/MeshLibrary.png",
    ["ICON_PLANEMESH"]      = "res/icon/PlaneMesh.png",
    ["ICON_MATERIAL"]       = "res/icon/CanvasItemMaterial.png",
    ["ICON_PREFAB"]         = "res/icon/PackedScene.png",
    ["ICON_SPOTLIGHT"]      = "res/icon/SpotLight3D.png",
    ["ICON_POINTLIGHT"]     = "res/icon/OmniLight3D.png",
    ["ICON_DIRECTIONALLIGHT"] = "res/icon/DirectionalLight3D.png",
    ["ICON_INFO"]           = "res/icon/Info.png",
    ["ICON_WARN"]           = "res/icon/Warn.png",
    ["ICON_ERROR"]          = "res/icon/Error.png",
    ["ICON_FILE_LIST"]      = "res/icon/FileList.png",
    ["ICON_FILE_SYSTEM"]    = "res/icon/Filesystem.png",
    ["ICON_ROOM_INSTANCE"]  = "res/icon/RoomInstance.png",
    ["ICON_PLAY"]           = "res/icon/Play.png",
    ["ICON_PAUSE"]          = "res/icon/Pause.png",
}

local icons = {}
return function(assetmgr)
    for k, v in pairs(icon_path) do
        icons[k] = assetmgr.resource("/pkg/tools.prefab_editor/" .. v, { compile = true })
    end
    local fs   = require "filesystem"
    icons.get_file_icon = function(path_str)
        local ext = tostring(fs.path(path_str):extension())
        if ext == ".lua" then
            return icons.ICON_SCRIPT
        elseif ext == ".shader" then
            return icons.ICON_SHADER
        elseif ext == ".glb" then
            return icons.ICON_MESHLIBRARY
        elseif ext == ".meshbin" then
            return icons.ICON_MESH
        elseif ext == ".material" then
            return icons.ICON_MATERIAL
        elseif ext == ".prefab" then
            return icons.ICON_PREFAB
        elseif ext == ".ozz" then
            local filename = tostring(fs.path(path_str):filename())
            if filename == "skeleton.ozz" then
                return icons.ICON_SKELETON3D
            end
            return icons.ICON_ANIMATION
        elseif ext == ".png" or ext == ".ktx" or ext == ".jpg" then
            return icons.ICON_IMAGE
        end
        return icons.ICON_FILE
    end
    return icons
end