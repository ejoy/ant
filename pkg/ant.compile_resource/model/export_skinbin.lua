local utility = require "model.utility"

local function GetSkinsForScene(model, scene)
    local open = {}
    local found = {}
    for _, nodeIndex in ipairs(scene.nodes) do
        open[nodeIndex] = true
    end
    while true do
        local nodeIndex = next(open)
        if nodeIndex == nil then
            break
        end
        found[nodeIndex] = true
        open[nodeIndex] = nil
        local node = model.nodes[nodeIndex+1]
        if node.children then
            for _, childIndex in ipairs(node.children) do
                open[childIndex] = true
            end
        end
    end
    local skins = {}
    for _, skin in ipairs(model.skins) do
        if #skin.joints ~= 0 and found[skin.joints[1]] then
            skins[#skins+1] = skin
        end
    end
    return skins
end

local function FindSkinRootJointIndices(model)
    local sceneIndex = model.scene or 0
    local scene = model.scenes[sceneIndex+1]
    local skins = GetSkinsForScene(model, scene)
    local mark = {}
    local roots = {}
    local function add_root(nodeIndex)
        if not mark[nodeIndex] then
            mark[nodeIndex] = true
            roots[#roots+1] = nodeIndex
        end
    end
    if #skins == 0 then
        for _, nodeIndex in ipairs(scene.nodes) do
            add_root(nodeIndex)
        end
        table.sort(roots)
        return roots
    end
    local parents = {}
    for nodeIndex, node in ipairs(model.nodes) do
        if node.children then
            for _, childIndex in ipairs(node.children) do
                parents[childIndex] = nodeIndex-1
            end
        end
    end
    local no_parent <const> = nil
    local visited <const> = true
    for _, skin in ipairs(skins) do
        if #skin.joints == 0 then
            goto continue
        end
        if skin.skeleton then
            parents[skin.skeleton] = visited
            skin.pivotPoint = skin.skeleton
            add_root(skin.skeleton)
            goto continue
        end

        local root = skin.joints[1]
        while root ~= visited and parents[root] ~= no_parent do
            root = parents[root]
        end
        if root ~= visited then
            add_root(root)
        end
        skin.pivotPoint = root
        ::continue::
    end
    table.sort(roots)
    return roots
end

local function FetchAccessor(model, accessorIndex)
    local accessor   = model.accessors[accessorIndex+1]
    local bufferView = model.bufferViews[accessor.bufferView+1]
    local buffer     = model.buffers[bufferView.buffer+1]
    return buffer.bin:sub(bufferView.byteOffset + 1, bufferView.byteOffset + bufferView.byteLength)
end

return function (status)
    local model = status.gltfscene
    local roots = FindSkinRootJointIndices(model)
    local jointIndex = 0
    local function BuildJointHierarchy(nodes)
        for _, nodeIndex in ipairs(nodes) do
            local node = model.nodes[nodeIndex+1]
            node.jointIndex = jointIndex
            jointIndex = jointIndex + 1
            local c = node.children
            if c then
                BuildJointHierarchy(c)
            end
        end
    end
    BuildJointHierarchy(roots)

    status.animation.skins = {}
    local math3d  = status.math3d
    local r2l_mat = math3d.ext_constant.R2L_MAT
    for skinidx, skin in ipairs(model.skins) do
        local resname = skin.name and ("skin_"..skin.name..".skinbin") or ("skin"..skinidx..".skinbin")
        local inverseBindMatrices = FetchAccessor(model, skin.inverseBindMatrices)
        local joints = skin.joints
        local jointsRemap  = {}
        for i = 1, #joints do
            local nodeIndex = joints[i]
            local node = model.nodes[nodeIndex+1]
            jointsRemap[i] = string.pack("<I2", assert(node.jointIndex))
        end
        local skinbin = {
            inverseBindMatrices = math3d.serialize(math3d.mul_array(math3d.array_matrix(inverseBindMatrices), r2l_mat)),
            jointsRemap = table.concat(jointsRemap),
        }
        utility.save_bin_file(status, "animations/"..resname, skinbin)
        status.animation.skins[skinidx] = resname
    end
end
