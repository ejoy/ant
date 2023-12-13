local icon_path = {
    ICON_FILE           = "res/icon/File.texture",
    ICON_FOLD           = "res/icon/Folder.texture",
    ICON_LOCK           = "res/icon/Lock.texture",
    ICON_UNLOCK         = "res/icon/Unlock.texture",
    ICON_VISIBLE        = "res/icon/GuiVisibilityVisible.texture",
    ICON_UNVISIBLE      = "res/icon/GuiVisibilityHidden.texture",
    ICON_SELECT         = "res/icon/ToolSelect.texture",
    ICON_MOVE           = "res/icon/ToolMove.texture",
    ICON_SCALE          = "res/icon/ToolScale.texture",
    ICON_ROTATE         = "res/icon/ToolRotate.texture",
    ICON_SCRIPT         = "res/icon/Script.texture",
    ICON_SHADER         = "res/icon/Shader.texture",
    ICON_IMAGE          = "res/icon/Image.texture",
    ICON_MESH           = "res/icon/Mesh.texture",
    ICON_OBJECT         = "res/icon/Object.texture",
    ICON_WORLD3D        = "res/icon/World3D.texture",
    ICON_ANIMATION      = "res/icon/Animation.texture",
    ICON_SKELETON3D     = "res/icon/Skeleton3D.texture",
    ICON_CAMERA3D       = "res/icon/Camera3D.texture",
    ICON_CAPSULEMESH    = "res/icon/CapsuleMesh.texture",
    ICON_CUBEMESH       = "res/icon/CubeMesh.texture",
    ICON_CYLINDERMESH   = "res/icon/CylinderMesh.texture",
    ICON_SPHEREMESH     = "res/icon/SphereMesh.texture",
    ICON_FAVORITES      = "res/icon/Favorites.texture",
    ICON_MESHLIBRARY    = "res/icon/MeshLibrary.texture",
    ICON_PLANEMESH      = "res/icon/PlaneMesh.texture",
    ICON_MATERIAL       = "res/icon/CanvasItemMaterial.texture",
    ICON_PREFAB         = "res/icon/PackedScene.texture",
    ICON_SPOTLIGHT      = "res/icon/SpotLight3D.texture",
    ICON_POINTLIGHT     = "res/icon/OmniLight3D.texture",
    ICON_DIRECTIONALLIGHT = "res/icon/DirectionalLight3D.texture",
    ICON_INFO           = "res/icon/Info.texture",
    ICON_WARN           = "res/icon/Warn.texture",
    ICON_ERROR          = "res/icon/Error.texture",
    ICON_FILE_LIST      = "res/icon/FileList.texture",
    ICON_FILE_SYSTEM    = "res/icon/Filesystem.texture",
    ICON_ROOM_INSTANCE  = "res/icon/RoomInstance.texture",
    ICON_PLAY           = "res/icon/Play.texture",
    ICON_PAUSE          = "res/icon/Pause.texture",
    ICON_RIGIDBODY3D    = "res/icon/RigidBody3D.texture",
    ICON_COLLISIONSHAPE3D   = "res/icon/CollisionShape3D.texture",
    ICON_COLLISIONPOLYGON3D = "res/icon/CollisionPolygon3D.texture",
    ICON_SLOT           = "res/icon/Slot.texture",
    ICON_PARTICLES3D    = "res/icon/Particles3D.texture",
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