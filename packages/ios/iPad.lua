local major, minor = ...

if major == 1 then
    -- iPad : iPad1,1, iPad1,2
    return {
        cpu = "Apple A4"
    }
elseif major == 2 then
    -- iPad 2    : iPad2,1, iPad2,2, iPad2,3, iPad2,4
    -- iPad mini : iPad2,5, iPad2,6, iPad2,7
    return {
        cpu = "Apple A5"
    }
elseif major == 3 then
    -- iPad 3 : iPad3,1, iPad3,2, iPad3,3
    -- iPad 4 : iPad3,4, iPad3,5, iPad3,6
    if minor <= 3 then
        return {
            cpu = "Apple A5X"
        }
    else
        return {
            cpu = "Apple A6X"
        }
    end
elseif major == 4 then
    -- iPad Air         : iPad4,1, iPad4,2, iPad4,3
    -- iPad mini Retina : iPad4,4, iPad4,5, iPad4,6
    -- iPad mini 3      : iPad4,7, iPad4,8, iPad4,9
    return {
        cpu = "Apple A7"
    }
elseif major == 5 then
    -- iPad mini 4 : iPad5,1, iPad5,2
    -- iPad Air 2  : iPad5,3, iPad5,4
    if minor <= 2 then
        return {
            cpu = "Apple A8"
        }
    elseif minor <= 4 then
        return {
            cpu = "Apple A8X"
        }
    end
elseif major == 6 then
    -- iPad Pro 9.7"  : iPad6,3,  iPad6,4
    -- iPad Pro 12.9" : iPad6,7,  iPad6,8
    -- iPad 5         : iPad6,11, iPad6,12
    if minor == 3 or minor == 4 or minor == 7 or minor == 8 then
        return {
            cpu = "Apple A9X"
        }
    elseif minor == 11 or minor == 12 then
        return {
            cpu = "Apple A9"
        }
    end
elseif major == 7 then
    -- iPad Pro 12.9" 2 : iPad7,1, iPad7,2
    -- iPad Pro 10.5"   : iPad7,3, iPad7,4
    -- iPad 6           : iPad7,5, iPad7,6
    if minor <= 4 then
        return {
            cpu = "Apple A10X"
        }
    elseif minor <= 6 then
        return {
            cpu = "Apple A10"
        }
    end
elseif major == 8 then
    -- iPad Pro 11"     : iPad8,1, iPad8,2, iPad8,3, iPad8,4
    -- iPad Pro 12.9" 3 : iPad8,5, iPad8,6, iPad8,7, iPad8,8
    return {
        cpu = "Apple A12X"
    }
elseif major == 11 then
    -- iPad mini 5 : iPad11,1, iPad11,2
    -- iPad Air 3  : iPad11,3, iPad11,4
    return {
        cpu = "Apple A12"
    }
end
