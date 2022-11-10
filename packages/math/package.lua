if not __ANT_RUNTIME__ then
    --large 
    if package.loaded.math3d then
        error "need init math3d MAXPAGE"
    end
    debug.getregistry().MATH3D_MAXPAGE = 10480
end

return {
    name = "ant.math",
    entry = "main",
    dependencies = {
    }
}
