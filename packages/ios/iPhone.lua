local major = ...

if major == 3 then
    -- iPhone 4 : iPhone3,1, iPhone3,2, iPhone3,3
    return {
        cpu = "Apple A4"
    }
elseif major == 4 then
    -- iPhone 4S : iPhone4,1
    return {
        cpu = "Apple A5"
    }
elseif major == 5 then
    -- iPhone 5  : iPhone5,1, iPhone5,2
    -- iPhone 5c : iPhone5,3, iPhone5,4
    return {
        cpu = "Apple A6"
    }
elseif major == 6 then
    -- iPhone 5S : iPhone6,1, iPhone6,2
    return {
        cpu = "Apple A7"
    }
elseif major == 7 then
    -- iPhone 6      : iPhone7,2
    -- iPhone 6 Plus : iPhone7,1
    return {
        cpu = "Apple A8"
    }
elseif major == 8 then
    -- iPhone 6S      : iPhone8,1
    -- iPhone 6S Plus : iPhone8,2
    -- iPhone SE      : iPhone8,4
    return {
        cpu = "Apple A9"
    }
elseif major == 9 then
    -- iPhone 7      : iPhone9,1, iPhone9,3
    -- iPhone 7 Plus : iPhone9,2, iPhone9,4
    return {
        cpu = "Apple A10"
    }
elseif major == 10 then
    -- iPhone 8      : iPhone10,1, iPhone10,4
    -- iPhone 8 Plus : iPhone10,2, iPhone10,5
    -- iPhone X      : iPhone10,3, iPhone10,6
    return {
        cpu = "Apple A11"
    }
elseif major == 11 then
    -- iPhone XS     : iPhone11,2,
    -- iPhone XS Max : iPhone11,4, iPhone11,6
    -- iPhone XR     : iPhone11,8
    return {
        cpu = "Apple A12"
    }
elseif major == 12 then
    -- iPhone 11         : iPhone12,1
    -- iPhone 11 Pro     : iPhone12,3
    -- iPhone 11 Pro Max : iPhone12,5
    return {
        cpu = "Apple A13"
    }
end
