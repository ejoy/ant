
local ctext=""

local rtable={
    ["r"]="color:ff0000 ",
    ["g"]="color:00ff00 ",
    ["b"]="color:0000ff ",
    ["u1"]="underline:false ",
    ["u2"]="underline:true ",
}
local default_color="color:ff0000"
local default_underline="underline:false"

--local os="aa a{</g/u2>bb}cc{</b>dd}ee"
--local s="{<color:ff0000 underline:false>aa a{<color:ff00ff underline:true>bb}cc{<color:00ff00>dd}ee}"

local groups={}
local groupsidx=1
local groupmap={}
local groupmapidx=1

local function prereplace(str)
    if str then
        str=string.gsub(str,"/(%w+)",rtable)
        if string.find(str,"%b{}")==1 then
            return str
        else
            return "{<"..default_color.." "..default_underline..">"..str.."}"
        end
    else return
    end
end

local function preorder(str)
   if str then
    str=string.sub(str,1+1,string.len(str)-1)
   else
    return
   end
   local group={}
   local curidx=groupsidx
   groupsidx=groupsidx+1
   groups[curidx]=group
   local gstart,gend=string.find(str,"%b<>")
   local grouptext=string.sub(str,gstart,gend)
   local textinfo=string.sub(str,gend+1,string.len(str))
   for k,v in string.gmatch(grouptext,"(%w+):(%w+)") do
        group[k]=v
   end
   local idx=1
   local mstart,mend,groupinfo,subtext=string.find(textinfo,"([^{}]+)(%b{})",idx)
   while mstart do
        for ch in string.gmatch(groupinfo,".")do
            ctext=ctext..ch
            groupmap[groupmapidx]=curidx
            groupmapidx=groupmapidx+1
        end

        preorder(subtext)

        idx=mend+1
        mstart,mend,groupinfo,subtext=string.find(textinfo,"([^{}]+)(%b{})",idx)
   end
   groupinfo=string.match(textinfo,"([^{}]+)",idx)
   for ch in string.gmatch(groupinfo,".")do
    ctext=ctext..ch
    groupmap[groupmapidx]=curidx
    groupmapidx=groupmapidx+1
   end

end

function ParseText(os)
    local s=prereplace(os)
    preorder(s)
    return ctext,groups,groupmap
end
