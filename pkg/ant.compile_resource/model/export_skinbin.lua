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

local function FindSkinRootJointIndices(model, scene)
    local skins = GetSkinsForScene(model, scene)
    local roots = {}
    if #skins  == 0 then
        for _, nodeIndex in ipairs(scene.nodes) do
            roots[#roots+1] = nodeIndex
        end
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
            roots[#roots+1] = skin.skeleton
            goto continue
        end

        local root = skin.joints[1]
        while root ~= visited and parents[root] ~= no_parent do
            root = parents[root]
        end
        if root ~= visited then
            roots[#roots+1] = root
        end
        ::continue::
    end
    return roots
end

local function fetch_skininfo(status, gltfscene, skin, remap)
    local math3d       = status.math3d
    local r2l_mat      = math3d.ext_constant.R2L_MAT
    local ibm_idx      = skin.inverseBindMatrices
    local ibm          = gltfscene.accessors[ibm_idx+1]
    local ibm_bv       = gltfscene.bufferViews[ibm.bufferView+1]
    local start_offset = ibm_bv.byteOffset + 1
    local end_offset   = start_offset + ibm_bv.byteLength
    local joints       = skin.joints
    local jointsRemap = {}
    for i = 1, #joints do
        jointsRemap[i] = string.pack("<I2", assert(remap[joints[i]]))
    end
    local buf = gltfscene.buffers[ibm_bv.buffer+1]
    local inverseBindMatrices = buf.bin:sub(start_offset, end_offset-1)
    inverseBindMatrices = math3d.serialize(math3d.mul_array(math3d.array_matrix(inverseBindMatrices), r2l_mat))
    return {
        inverseBindMatrices = inverseBindMatrices,
        jointsRemap = table.concat(jointsRemap),
    }
end

return function (status)
    local gltfscene = status.gltfscene
    local sceneidx = gltfscene.scene or 0
    local scene = gltfscene.scenes[sceneidx+1]
    local roots = FindSkinRootJointIndices(gltfscene, scene)
    local jointIndex = 0
    local remap = {}
    local function ImportNode(nodes)
        for _, nodeIndex in ipairs(nodes) do
            remap[nodeIndex] = jointIndex
            jointIndex = jointIndex + 1
            local node = gltfscene.nodes[nodeIndex+1]
            local c = node.children
            if c then
                ImportNode(c)
            end
        end
    end
    ImportNode(roots)

    status.animation.skins = {}
    for skinidx, skin in ipairs(gltfscene.skins) do
        local skinname = skin.name and ("skin_"..skin.name) or ("skin"..skinidx)
        local resname = skinname..".skinbin"
        utility.save_bin_file(status, "animations/"..resname, fetch_skininfo(status, gltfscene, skin, remap))
        status.animation.skins[skinidx] = resname
    end
end
