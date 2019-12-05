local datalist = require 'datalist'
return function (w, s)
    w:create_entity_v2(datalist.parse(s))
end
