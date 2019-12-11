local datalist = require 'datalist'
return function (w, s)
    w:create_entity(datalist.parse(s))
end
