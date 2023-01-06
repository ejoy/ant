local efkobj= require "efkobj"
return {
    loader = function (filename)
        return {
            handle = efkobj.ctx:create(filename),
        }
    end,
    unloader = function (res)

    end
}