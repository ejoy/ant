local icon_path = {
    ICON_FILE           = "resource/icon/File.texture",
    ICON_FOLD           = "resource/icon/Folder.texture",
    ICON_LOCK           = "resource/icon/Lock.texture",
    ICON_UNLOCK         = "resource/icon/Unlock.texture",
    ICON_VISIBLE        = "resource/icon/GuiVisibilityVisible.texture",
    ICON_UNVISIBLE      = "resource/icon/GuiVisibilityHidden.texture",
    ICON_SELECT         = "resource/icon/ToolSelect.texture",
    ICON_MOVE           = "resource/icon/ToolMove.texture",
    ICON_SCALE          = "resource/icon/ToolScale.texture",
    ICON_ROTATE         = "resource/icon/ToolRotate.texture",
    ICON_SCRIPT         = "resource/icon/Script.texture",
    ICON_SHADER         = "resource/icon/Shader.texture",
    ICON_IMAGE          = "resource/icon/Image.texture",
    ICON_MESH           = "resource/icon/Mesh.texture",
    ICON_OBJECT         = "resource/icon/Object.texture",
    ICON_WORLD3D        = "resource/icon/World3D.texture",
    ICON_ANIMATION      = "resource/icon/Animation.texture",
    ICON_SKELETON3D     = "resource/icon/Skeleton3D.texture",
    ICON_CAMERA3D       = "resource/icon/Camera3D.texture",
    ICON_CAPSULEMESH    = "resource/icon/CapsuleMesh.texture",
    ICON_CUBEMESH       = "resource/icon/CubeMesh.texture",
    ICON_CYLINDERMESH   = "resource/icon/CylinderMesh.texture",
    ICON_SPHEREMESH     = "resource/icon/SphereMesh.texture",
    ICON_FAVORITES      = "resource/icon/Favorites.texture",
    ICON_MESHLIBRARY    = "resource/icon/MeshLibrary.texture",
    ICON_PLANEMESH      = "resource/icon/PlaneMesh.texture",
    ICON_MATERIAL       = "resource/icon/CanvasItemMaterial.texture",
    ICON_PREFAB         = "resource/icon/PackedScene.texture",
    ICON_SPOTLIGHT      = "resource/icon/SpotLight3D.texture",
    ICON_POINTLIGHT     = "resource/icon/OmniLight3D.texture",
    ICON_DIRECTIONALLIGHT = "resource/icon/DirectionalLight3D.texture",
    ICON_INFO           = "resource/icon/Info.texture",
    ICON_WARN           = "resource/icon/Warn.texture",
    ICON_ERROR          = "resource/icon/Error.texture",
    ICON_FILE_LIST      = "resource/icon/FileList.texture",
    ICON_FILE_SYSTEM    = "resource/icon/Filesystem.texture",
    ICON_ROOM_INSTANCE  = "resource/icon/RoomInstance.texture",
    ICON_PLAY           = "resource/icon/Play.texture",
    ICON_PAUSE          = "resource/icon/Pause.texture",
    ICON_RIGIDBODY3D    = "resource/icon/RigidBody3D.texture",
    ICON_COLLISIONSHAPE3D   = "resource/icon/CollisionShape3D.texture",
    ICON_COLLISIONPOLYGON3D = "resource/icon/CollisionPolygon3D.texture",
    ICON_SLOT           = "resource/icon/Slot.texture",
    ICON_PARTICLES3D    = "resource/icon/Particles3D.texture",
}

local icons = {
    init = function(self, assetmgr)
        for k, v in pairs(icon_path) do
            self[k] = assetmgr.resource("/pkg/tools.editor/" .. v, { compile = true })
        end
    end,
    get_file_icon = function(self, path_str)
        local fs   = require "filesystem"
        local ext = tostring(fs.path(path_str):extension())
        if ext == ".lua" then
            return self.ICON_SCRIPT
        elseif ext == ".shader" then
            return self.ICON_SHADER
        elseif ext == ".glb" or ext == ".fbx" then
            return self.ICON_MESHLIBRARY
        elseif ext == ".meshbin" then
            return self.ICON_MESH
        elseif ext == ".material" then
            return self.ICON_MATERIAL
        elseif ext == ".prefab" then
            return self.ICON_PREFAB
        elseif ext == ".ozz" then
            return self.ICON_ANIMATION
        elseif ext == ".png" or ext == ".ktx" or ext == ".jpg" then
            return self.ICON_IMAGE
        elseif ext == ".efk" then
        end
        return self.ICON_FILE
    end
}

return icons