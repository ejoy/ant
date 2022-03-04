local renderpkg = import_package "ant.render"
local fbmgr = renderpkg.fbmgr
local sampler = renderpkg.sampler
return {
    is_panorama_tex = function(texinfo)
        return texinfo.depth == 1 and texinfo.width == texinfo.height*2
    end,
    check_create_cubemap_tex = function (ti, cm_rbidx)
        local facesize = ti.height // 2
        if cm_rbidx ~= nil then
            fbmgr.resize_rb(cm_rbidx, facesize)
        else
            cm_rbidx = fbmgr.create_rb{format="RGBA32F", size=facesize, layers=1, mipmap=true, flags=sampler.sampler_flag {
                MIN="LINEAR",
                MAG="LINEAR",
                MIP="LINEAR",
                U="CLAMP",
                V="CLAMP",
                W="CLAMP",
                RT="RT_ON",
            }, cubemap=true}
        end

        return cm_rbidx
    end
}