local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr

local S = ecs.system "infinite_far_plane_test_system"

local function compare_camera(inv_z, n, f, ortho)
    local p, infp
    if ortho then
        p = math3d.projmat({l=-1,r=1,t=1,b=-1,n=n,f=f,ortho=true}, inv_z)
        infp = math3d.projmat({l=-1,r=1,t=1,b=-1,n=n,f=f,ortho=true}, inv_z, true)
    else
        p = math3d.projmat({n=n, f=f, fov=60, aspect=4/3}, inv_z)
        infp = math3d.projmat({n=n, f=f, fov=60, aspect=4/3}, inv_z, true)
    end
    local updir = math3d.vector(0, 1, 0)
    local eyepos = math3d.vector(0, 0, 0)
    local direction = math3d.normalize(math3d.vector(0, 0, 1))
    local v = math3d.lookto(eyepos, direction, updir)
    local vp = math3d.mul(p, v)
    local vinfp = math3d.mul(infp, v)

    local zz_n, ww_n = math3d.index(math3d.transform(vp, math3d.vector(0, 0, n), 1), 3, 4)
    local zzinf_n, wwinf_n = math3d.index(math3d.transform(vinfp, math3d.vector(0, 0, n), 1), 3, 4)

    local zz_m, ww_m = math3d.index(math3d.transform(vp, math3d.vector(0, 0, (n+f)*0.0005), 1), 3, 4)
    local zzinf_m, wwinf_m = math3d.index(math3d.transform(vinfp, math3d.vector(0, 0, (n+f)*0.0005), 1), 3, 4)

    local zz_f, ww_f = math3d.index(math3d.transform(vp, math3d.vector(0, 0, f), 1), 3, 4)
    local zzinf_f, wwinf_f = math3d.index(math3d.transform(vinfp, math3d.vector(0, 0, f), 1), 3, 4)
    
    local ndf_n, ndf_n_inf = zz_n / ww_n, zzinf_n / wwinf_n
    local ndf_m, ndf_m_inf = zz_m / ww_m, zzinf_m / wwinf_m
    local ndf_f, ndf_f_inf = zz_f / ww_f, zzinf_f / wwinf_f    
    return ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf
end


function S:data_changed()
    local ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(false, 0.1, 10000)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf= compare_camera(true, 0.1, 10000)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(false, 0.01, 1000)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(true, 0.01, 2000)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(false, 0.1, 10000, true)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf= compare_camera(true, 0.1, 20000, true)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(false, 0.01, 1000, true)
    ndf_n, ndf_n_inf, ndf_m, ndf_m_inf, ndf_f, ndf_f_inf = compare_camera(true, 0.01, 2000, true)
end