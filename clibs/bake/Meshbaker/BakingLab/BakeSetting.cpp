#include "PCH.h"

#include "BakeSetting.h"

BakeSetting s_BakeSetting;

const BakeSetting& GetBakeSetting(){
    return s_BakeSetting;
}