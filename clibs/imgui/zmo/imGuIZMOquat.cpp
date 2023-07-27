//------------------------------------------------------------------------------
//  Copyright (c) 2018-2020 Michele Morrone
//  All rights reserved.
//
//  https://michelemorrone.eu - https://BrutPitt.com
//
//  twitter: https://twitter.com/BrutPitt - github: https://github.com/BrutPitt
//
//  mailto:brutpitt@gmail.com - mailto:me@michelemorrone.eu
//  
//  This software is distributed under the terms of the BSD 2-Clause license
//------------------------------------------------------------------------------
#include "imGuIZMOquat.h"

ImVector<vec3> imguiGizmo::sphereVtx;
ImVector<int>  imguiGizmo::sphereTess;
ImVector<vec3> imguiGizmo::arrowVtx[4];
ImVector<vec3> imguiGizmo::arrowNorm[4];
ImVector<vec3> imguiGizmo::cubeVtx;
ImVector<vec3> imguiGizmo::cubeNorm;
ImVector<vec3> imguiGizmo::planeVtx;
ImVector<vec3> imguiGizmo::planeNorm;
bool imguiGizmo::solidAreBuilded = false;
bool imguiGizmo::dragActivate = false;
//
//  Settings
//
//      axes/arrow are composed of cone (or pyramid) and cylinder 
//      (or parallelepiped): this solid are builded at first instance
//      and will have same slices/radius/length for all controls in your 
//      applications but can be resized proportionally with a reductin
//      factor: solidResizeFactor and  axesResizeFactor.
//      Same thing for the colors of sphere tessellation, while color
//      of axes and cube are fixed
//
//      Solid/axes settings can be set one only one time before your widget
//      while solidResizeFactor and  axesResizeFactor settings must 
//      be call before and always of your widget, every redraw... and
//      restored after use... like push/pop
//      ... I avoided creating a push/pop mechanism
////////////////////////////////////////////////////////////////////////////
 
// arrow/axes components
///////////////////////////////////////
int   imguiGizmo::coneSlices  = 4;
float imguiGizmo::coneRadius = 0.07f;
float imguiGizmo::coneLength = 0.37f;


int   imguiGizmo::cylSlices   = 7;
float imguiGizmo::cylRadius  = 0.02f; // sizeCylLength = defined in base to control size


// Sphere components
///////////////////////////////////////
float imguiGizmo::sphereRadius = .27f;
int imguiGizmo::sphereTessFactor = imguiGizmo::sphereTess4;

// Cube components
///////////////////////////////////////
float imguiGizmo::cubeSize     = .05f;

// Plane components
///////////////////////////////////////
float imguiGizmo::planeSize      = .33f;
float imguiGizmo::planeThickness = .015f;

// Axes resize
///////////////////////////////////////
vec3 imguiGizmo::axesResizeFactor(.95f, 1.0f, 1.0f);
vec3 imguiGizmo::savedAxesResizeFactor = imguiGizmo::axesResizeFactor;

// Solid resize
///////////////////////////////////////
float imguiGizmo::solidResizeFactor = 1.0f;
float imguiGizmo::savedSolidResizeFactor = imguiGizmo::solidResizeFactor;

// Direction arrow color
///////////////////////////////////////
ImVec4 imguiGizmo::directionColor(1.0f, 1.0f, 0.0f, 1.0f);
ImVec4 imguiGizmo::savedDirectionColor = imguiGizmo::directionColor;

// Plane color
///////////////////////////////////////
ImVec4 imguiGizmo::planeColor(0.0f, 0.5f, 1.0f, STARTING_ALPHA_PLANE);
ImVec4 imguiGizmo::savedPlaneColor = imguiGizmo::planeColor;

// Sphere Colors 
///////////////////////////////////////
ImU32 imguiGizmo::sphereColors[2] = { 0xff401010, 0xffc0a0a0 }; // Tessellation colors
ImU32 imguiGizmo::savedSphereColors[2]  = { 0xff401010, 0xffc0a0a0 }; 
//ImU32 spherecolorA=0xff005cc0, spherecolorB=0xffc05c00;

// Gizmo mouse settings
///////////////////////////////////////
float imguiGizmo::gizmoFeelingRot = 1.f; // >1 more mouse sensibility, <1 less mouse sensibility

#ifndef IMGUIZMO_USE_ONLY_ROT
float imguiGizmo::dollyScale = 1.f, imguiGizmo::panScale = 1.f;
vgModifiers imguiGizmo::panMod = vg::evControlModifier, imguiGizmo::dollyMod = vg::evShiftModifier;
#endif

//
//  for all gizmo3D
//
//      input:
//          size:   dimension of the control
//          mode:   visualization mode: axis starting from origin, fullAxis 
//                  (whit or w/o solid at 0,0,0) or only one arrow for direction
//
//      other settings (to call before and always of your control):
//          dimesion solid, axes, and arrow, slice of poligons end over: view 
//          section "settings of class declaration", these these values are valid for 
//          ALL controls in your application, because the lists of triangles/quads, 
//          which compose the solids, are builded one time with the first 
//          instance ... and NOT every redraw
//
//          solidResizeFactor - axesResizeFactor 
//              can resize axes or solid, respectively (helper func)
////////////////////////////////////////////////////////////////////////////
namespace ImGui
{
//  Quaternion control 
//      in/out:  
//          - quat (quaternion) rotation
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, quat& q, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings(mode & ~g.modeDual);

    g.qtV = q;

    bool ret = g.drawFunc(label, size);
    if(ret) q = g.qtV;

    return ret;
}
//  Angle/Axes control 
//      in/out: 
//          - vec4 - X Y Z vector/axes components - W angle of rotation
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec4& axis_angle, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings(mode & ~g.modeDual);

    return g.getTransforms(g.qtV, label, axis_angle, size);
}
//  Direction control  
//      in/out: 
//          - vec3 - X Y Z vector/axes components
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& dir, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings(mode & (imguiGizmo::modeDirection | imguiGizmo::modeDirPlane) ? mode : imguiGizmo::modeDirection); 

    return g.getTransforms(g.qtV, label, dir, size);
}
//  2 Manipulators -> 2 Quaternions 
//      in/out: 
//          - axes (quaternion) for full control - LeftClick 
//          - spot (quaternion) for full control - RightClick
//
//                both pressed buttons... rotate together
//                ctrl-Shift-Alt mods, for X-Y-Z rotations (respectivally)
//                are abilitated on both ... also together!
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, quat& axes, quat& spot, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);
    
    g.qtV = axes; g.qtV2 = spot;
    
    bool ret = g.drawFunc(label, size);
    if(ret) { axes = g.qtV; spot = g.qtV2; }

    return ret;
}
//  2 Manipulators -> Quaternion and vec3
//      in/out: 
//          - axes (quaternion) for full control - LeftClick 
//          - spot (vec3)       for full control - RightClick
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, quat& axes, vec3& spotDir, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);

    g.qtV = axes;

    bool ret = g.getTransforms(g.qtV2, label, spotDir, size);
    if(ret) axes = g.qtV;
    return ret;
}
//  2 Manipulators -> Quaternion and vec4
//      in/out: 
//          - axes (quaternion) for full control - LeftClick 
//          - spot (vec4)       for full control - RightClick
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, quat& axes, vec4& axesAngle, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);

    g.qtV = axes;

    bool ret = g.getTransforms(g.qtV2, label, axesAngle, size);
    if(ret) axes = g.qtV;
    return ret;

}
#ifndef IMGUIZMO_USE_ONLY_ROT
//  Quaternion control + Pan & Dolly
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z)
//          - quat (quaternion) rotation
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, quat& q, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings((mode | g.modePanDolly) & ~g.modeDual );

    g.qtV = q;
    g.posPanDolly = vPanDolly;

    bool ret = g.drawFunc(label, size);
    if(ret) {
        q = g.qtV;
        vPanDolly = g.posPanDolly;
    }

    return ret;
}
//  Angle/Axes control + Pan & Dolly 
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z)
//          - vec4 - X Y Z vector/axes components - W angle of rotation
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, vec4& axis_angle, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings(mode & ~g.modeDual | g.modePanDolly);
    g.posPanDolly = vPanDolly;

    bool ret = g.getTransforms(g.qtV, label, axis_angle, size);

    if(ret) vPanDolly = g.posPanDolly;
    return ret;
}
//  Direction control + Pan & Dolly 
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z)
//          - vec3 - X Y Z vector/axes components
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, vec3& dir, float size, const int mode)
{
    imguiGizmo g;
    g.modeSettings(mode & ((imguiGizmo::modeDirection | imguiGizmo::modeDirPlane) ? mode : imguiGizmo::modeDirection)  | g.modePanDolly); 
    g.posPanDolly = vPanDolly;

    bool ret = g.getTransforms(g.qtV, label, dir, size);

    if(ret) vPanDolly = g.posPanDolly;
    return ret;

}
//  2 Manipulators -> 2 Quaternions  + Pan & Dolly
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z) - default: Ctrl /Shift
//          - axes (quaternion) for full control - LeftClick 
//          - spot (quaternion) for full control - RightClick
//
//                both pressed buttons... rotate together
//                ctrl-Shift-Alt mods, for X-Y-Z rotations (respectivally)
//                are abilitated on both ... also together!
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, quat& axes, quat& spot, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);
    g.posPanDolly = vPanDolly;
    
    g.qtV = axes; g.qtV2 = spot;
    
    bool ret = g.drawFunc(label, size);
    if(ret) { vPanDolly = g.posPanDolly; axes = g.qtV; spot = g.qtV2; }

    return ret;
}
//  2 Manipulators -> Quaternion and vec3  + Pan & Dolly
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z) - default: Ctrl /Shift
//          - axes (quaternion) for full control - LeftClick 
//          - spot (vec3)       for full control - RightClick
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, quat& axes, vec3& spotDir, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);
    g.posPanDolly = vPanDolly;

    g.qtV = axes;

    bool ret = g.getTransforms(g.qtV2, label, spotDir, size);
    if(ret) { vPanDolly = g.posPanDolly; axes = g.qtV; }
    return ret;
}
//  2 Manipulators -> Quaternion and vec4  + Pan & Dolly
//      in/out: 
//          - vec3 Pan(x,y) Dolly(z) - default: Ctrl /Shift
//          - axes (quaternion) for full control - LeftClick 
//          - spot (vec4)       for full control - RightClick
////////////////////////////////////////////////////////////////////////////
bool gizmo3D(const char* label, vec3& vPanDolly, quat& axes, vec4& axesAngle, float size, const int mode)
{
    imguiGizmo g;
    g.setDualMode(mode);
    g.posPanDolly = vPanDolly;

    g.qtV = axes;

    bool ret = g.getTransforms(g.qtV2, label, axesAngle, size);
    if(ret) { vPanDolly = g.posPanDolly; axes = g.qtV; }
    return ret;

}
#endif

} // namespace ImGui

static inline int clamp(int v, int mn, int mx)
{
    return (v < mn) ? mn : (v > mx) ? mx : v; 
}

//
//  LightEffect
//      faster but minus cute/precise.. ok for sphere
////////////////////////////////////////////////////////////////////////////
inline ImU32 addLightEffect(ImU32 color, float light)
{         
    float l = ((light<.6f) ? .6f : light) * .8f;  
    float lc = light * 80.0f;                    // ambient component 
    return   clamp(ImU32((( color      & 0xff)*l + lc)),0,255)        |
            (clamp(ImU32((((color>>8)  & 0xff)*l + lc)),0,255) <<  8) |
            (clamp(ImU32((((color>>16) & 0xff)*l + lc)),0,255) << 16) |
            (ImU32(ImGui::GetStyle().Alpha * (color>>24))  << 24);  
}
//
//  LightEffect
//      with distance attenuatin
////////////////////////////////////////////////////////////////////////////
inline ImU32 addLightEffect(const vec4 &color, float light, float atten)
{                          
    vec3 l((light<.5) ? .5f : light); 
    vec3 a(atten>.25  ? .25f : atten);
    vec3 c(((vec3(color) + l*.5f) * l) *.75f + a*vec3(color)*.45f +a*.25f);

    const float alpha = color.a * ImGui::GetStyle().Alpha; //ImGui::GetCo(ImGuiCol_FrameBg).w;
    return ImGui::ColorConvertFloat4ToU32(ImVec4(c.x, c.y, c.z, alpha));
}

inline ImU32 addLightEffect(ImU32 color, float light,  float atten)
{                        
    vec4 c(float(color & 0xff)/255.f,float((color>>8) & 0xff)/255.f,float((color>>16) & 0xff)/255.f, 1.0f);
    return addLightEffect(c, light, atten);
}

//  inline helper drawing functions
////////////////////////////////////////////////////////////////////////////
typedef vec3 & (*ptrFunc)(vec3 &);


inline vec3 &adjustPlane(vec3 &coord)
{
    coord.x = (coord.x > 0.0f) ? ( 2.5f * coord.x - 1.6f) : coord.x ;
    coord.x = (coord.x)*.5f+.5f + (coord.x>0 ? -imguiGizmo::planeThickness : imguiGizmo::planeThickness) * imguiGizmo::solidResizeFactor;
    coord *= vec3(1.0f, 2.0f, 2.0f);
    return coord;
}

inline vec3 &adjustDir(vec3 &coord)
{
    coord.x = (coord.x > 0.0f) ? ( 2.5f * coord.x - 1.6f) : coord.x + 0.1f;
    coord *= vec3(1.0f, 3.0f, 3.0f);
    return coord;
}

inline vec3 &adjustSpotCyl(vec3 &coord)
{
    const float halfCylMinusCone = 1.0f - imguiGizmo::coneLength;
    coord.x = (coord.x*.075f - 2.0f +( halfCylMinusCone - halfCylMinusCone*.075f)); //cyl begin where cone end
    return coord;

}
inline vec3 &adjustSpotCone(vec3 &coord)
{
    coord.x-= 2.00f;
    return coord;
}

inline vec3 fastRotate (int axis, vec3 &v)
{
    return ((axis == imguiGizmo::axisIsY) ? vec3(-v.y, v.x, v.z) : // rotation Z 90'
           ((axis == imguiGizmo::axisIsZ) ? vec3(-v.z, v.y, v.x) : // rotation Y 90'
                                          v));
}
////////////////////////////////////////////////////////////////////////////
//
//  Draw imguiGizmo
//      
////////////////////////////////////////////////////////////////////////////
bool imguiGizmo::drawFunc(const char* label, float size)
{

    ImGuiIO& io = ImGui::GetIO();
    ImGuiStyle& style = ImGui::GetStyle();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();

    const float arrowStartingPoint = (axesOriginType & imguiGizmo::sphereAtOrigin) ? sphereRadius * solidResizeFactor:
                                    ((axesOriginType & imguiGizmo::cubeAtOrigin  ) ? cubeSize     * solidResizeFactor: 
                                                                                   cylRadius * .5);
    // if modeDual... leave space for draw light arrow
    vec3 resizeAxes( ((drawMode&modeDual) && (axesResizeFactor.x>.75f)) ? vec3(.75f,axesResizeFactor.y, axesResizeFactor.z) : axesResizeFactor);

    //  build solids... once!
    ///////////////////////////////////////
    if (!solidAreBuilded)  {
        const float arrowBgn = -1.0f, arrowEnd = 1.0f;     

        buildCone    (arrowEnd - coneLength, arrowEnd, coneRadius, coneSlices);
        buildCylinder(arrowBgn, arrowEnd - coneLength, cylRadius , cylSlices );
        buildSphere(sphereRadius, sphereTessFactor);
        buildCube(cubeSize);
        buildPlane(planeSize);
        solidAreBuilded = true;
    }

    ImGui::PushID(label);
    ImGui::BeginGroup();

    bool value_changed = false;

    ImVec2 controlPos(ImGui::GetCursorScreenPos());

    const float squareSize = size; //std::min(ImGui::CalcItemWidth(), size);
    const float halfSquareSize = squareSize*.5;
    const ImVec2 innerSize(squareSize,squareSize);

    bool highlighted = false;
    ImGui::InvisibleButton("imguiGizmo", innerSize);

    bool vgModsActive = false;
    vgModifiers vgMods = vg::evNoModifier;

    if(io.KeyCtrl)  { vgMods |= vg::evControlModifier; vgModsActive = true; }
    if(io.KeyAlt)   { vgMods |= vg::evAltModifier;     vgModsActive = true; }
    if(io.KeyShift) { vgMods |= vg::evShiftModifier;   vgModsActive = true; }
    if(io.KeySuper) { vgMods |= vg::evSuperModifier;   vgModsActive = true; }

    vg::vImGuIZMO track;
    //  getTrackball
    //      in : q -> quaternion to which applay rotations
    //      out: q -> quaternion with rotations
    ////////////////////////////////////////////////////////////////////////////
    auto getTrackball = [&] (quat &q) {
        ImVec2 mouse = ImGui::GetMousePos() - controlPos;

        track.viewportSize(innerSize.x, innerSize.y);
        track.setRotation(q);
        track.setGizmoFeeling(gizmoFeelingRot);
#ifndef IMGUIZMO_USE_ONLY_ROT
        if(drawMode&modePanDolly || io.MouseWheel!=0) {
            float screenFactor = 1.f/(io.DisplaySize.x<io.DisplaySize.y ? io.DisplaySize.x : io.DisplaySize.y);
            track.setPosition(posPanDolly);
            track.setDollyControl(buttonPanDolly, dollyMod);
            track.setPanControl(buttonPanDolly, panMod);
            track.setPanScale(screenFactor*panScale);
            track.setDollyScale(screenFactor*dollyScale);
            track.wheel(0.f, io.MouseWheel);
            track.motionImmediateMode(mouse.x, mouse.y, io.MouseDelta.x, io.MouseDelta.y, vgMods);
            // get new rotation only if !Pan && ! Dolly
            if((!track.isDollyActive() && !track.isPanActive() && io.MouseWheel==0)) q = track.getRotation();
            else                                       posPanDolly = track.getPosition();
        } else {
            track.imGuIZMO_BASE_CLASS::motionImmediateMode(mouse.x, mouse.y, io.MouseDelta.x, io.MouseDelta.y, vgMods);
            q = track.getRotation();
        }
#else
        track.motionImmediateMode(mouse.x, mouse.y, io.MouseDelta.x, io.MouseDelta.y, vgMods);
        q = track.getRotation();
#endif
        value_changed = true; // if getTrackball() called, value is changed
    };

    // LeftClick
    if (ImGui::IsItemActive()) {
        highlighted = true;
        if(ImGui::IsMouseDragging(0))                          getTrackball(qtV);        
        if((drawMode&modeDual) && ImGui::IsMouseDragging(1))   getTrackball(qtV2); // if dual mode... move together
        //if((drawMode&modeDual) && ImGui::IsMouseDragging(2)) { getTrackball(qtV);  getTrackball(qtV2); } // middle if dual mode... move together

        ImColor col(style.Colors[ImGuiCol_FrameBgActive]);
        col.Value.w*=ImGui::GetStyle().Alpha;
        draw_list->AddRectFilled(controlPos, controlPos + innerSize, col, style.FrameRounding);
    } else {  // eventual right click... only dualmode
        highlighted = ImGui::IsItemHovered();
        if(highlighted && (drawMode&modeDual) && ImGui::IsMouseDragging(1)) getTrackball(qtV2);
        else if(highlighted && (drawMode&modeDual) && ImGui::IsMouseDragging(2)) { getTrackball(qtV);  getTrackball(qtV2); }
#ifndef IMGUIZMO_USE_ONLY_ROT
        else if(highlighted && io.MouseWheel!=0) getTrackball(qtV);
#endif

        ImColor col(highlighted ? style.Colors[ImGuiCol_FrameBgHovered]: style.Colors[ImGuiCol_FrameBg]);
        col.Value.w*=ImGui::GetStyle().Alpha;
        draw_list->AddRectFilled(controlPos, controlPos + innerSize, col, style.FrameRounding);
    }


    draw_list->PushClipRect(controlPos, controlPos + innerSize, true);

    const ImVec2 wpUV = ImGui::GetFontTexUvWhitePixel(); //culling versus
    ImVec2 uv[4]; ImU32 col[4]; //buffers to storetransformed vtx & col for PrimVtx & PrimQuadUV

    quat _q(normalize(qtV)); 

    //  Just a "few" lambdas... 
    //////////////////////////////////////////////////////////////////
    auto normalizeToControlSize = [&] (float x, float y) {
        return controlPos + ImVec2(x,-y) * halfSquareSize + ImVec2(halfSquareSize,halfSquareSize); //drawing from 0,0 .. no borders
    };

    auto returnSizeFromRatio = [&] (float ratio) { return squareSize * ratio; };

    //////////////////////////////////////////////////////////////////
    auto addTriangle = [&] ()
    {   // test cull dir        
        if(cross(vec2(uv[1].x-uv[0].x, uv[1].y-uv[0].y), 
                 vec2(uv[2].x-uv[0].x, uv[2].y-uv[0].y)) > 0) { uv[1] = uv[2] = uv[0]; }

        for(int i=0; i<3; i++) draw_list->PrimVtx(uv[i], wpUV, col[i]);
    };

    //////////////////////////////////////////////////////////////////
    auto addQuad = [&] (ImU32 colLight)
    {   // test cull dir
        if(cross(vec2(uv[1].x-uv[0].x, uv[1].y-uv[0].y), 
                 vec2(uv[3].x-uv[0].x, uv[3].y-uv[0].y)) > 0) { uv[3] = uv[1] = uv[2] = uv[0]; }

        draw_list->PrimQuadUV(uv[0],uv[1],uv[2],uv[3], wpUV, wpUV, wpUV, wpUV, colLight); 
    };

    //////////////////////////////////////////////////////////////////
    auto drawSphere = [&] () 
    {
        draw_list->PrimReserve(sphereVtx.size(), sphereVtx.size()); // num vert/indices 
        auto itTess = sphereTess.begin();
        for(auto itVtx = sphereVtx.begin(); itVtx != sphereVtx.end(); )  {
            for(int h=0; h<3; h++, itTess++) {
                vec3 coord = _q  * (*itVtx++ * solidResizeFactor);        //Rotate

                uv[h] = normalizeToControlSize(coord.x,coord.y);
                const float drawSize = sphereRadius * solidResizeFactor;
                col[h] = addLightEffect(sphereColors[*itTess], (-drawSize*.5f + (coord.z*coord.z) / (drawSize*drawSize))); 
                //col[h] = colorLightedY(sphereCol[i++], (-sizeSphereRadius.5f + (coord.z*coord.z) / (sizeSphereRadius*sizeSphereRadius)), coord.z); 
            }
            addTriangle();
        }
    };

    //////////////////////////////////////////////////////////////////
    auto drawCube = [&] ()  
    {
        draw_list->PrimReserve(cubeNorm.size()*6, cubeNorm.size()*4); // num vert/indices 
        for(vec3* itNorm = cubeNorm.begin(), *itVtx  = cubeVtx.begin() ; itNorm != cubeNorm.end();) {
            vec3 coord;
            vec3 norm = _q * *itNorm;
            for(int i = 0; i<4; ) {
                coord = _q  * (*itVtx++ * solidResizeFactor);
                uv[i++] = normalizeToControlSize(coord.x,coord.y);
            }                    
            addQuad(addLightEffect(vec4(abs(*itNorm++),1.0f), norm.z, coord.z));
        }
    };

    //////////////////////////////////////////////////////////////////
    auto drawPlane = [&] ()  
    {
        draw_list->PrimReserve(planeNorm.size()*6, planeNorm.size()*4); // num vert/indices 
        for(auto itNorm = planeNorm.begin(), itVtx  = planeVtx.begin() ; itNorm != planeNorm.end();) {
            vec3 coord;
            vec3 norm = _q * *itNorm;
            for(int i = 0; i<4; ) {
                coord = _q  * (*itVtx++ * solidResizeFactor);
                uv[i++] = normalizeToControlSize(coord.x,coord.y);
            }                    
            itNorm++;
            addQuad(addLightEffect(vec4(planeColor.x, planeColor.y, planeColor.z, planeColor.w), norm.z, coord.z));
        }
    };

    //////////////////////////////////////////////////////////////////
    auto drawAxes = [&] (int side) 
    {   
        for(int n = 0; n < 4; n++) { //Arrow: 2 Cone -> (Surface + cap) + 2 Cyl -> (Surface + cap)
            for(int arrowAxis = 0; arrowAxis < 3; arrowAxis++) { // draw 3 axes
                vec3 arrowCoord(0.0f, 0.0f, 0.0f); arrowCoord[arrowAxis] = 1.0f; // rotate on 3 axis (arrow -> X, Y, Z ) in base to current arrowAxis
                const float arrowCoordZ = vec3(_q*arrowCoord).z; //.Rotate

                const int i = (arrowCoordZ > 0) ? 3 - n : n; //painter algorithm: before farthest

                bool skipCone =true;

                if((side == backSide  && arrowCoordZ > 0) || (side == frontSide && arrowCoordZ <= 0)) {
                    if (!showFullAxes && (i == CYL_CAP)) continue; // skip if cylCap is hidden
                    if (i <= CONE_CAP) continue;  // do not draw cone
                    else skipCone = false;
                }

                auto *ptrVtx = arrowVtx+i;
                draw_list->PrimReserve(ptrVtx->size(), ptrVtx->size()); // // reserve vtx

                for(auto itVtx = ptrVtx->begin(), itNorm = (arrowNorm+i)->begin(); itVtx != ptrVtx->end(); ) { //for all Vtx
#if !defined(imguiGizmo_INTERPOLATE_NORMALS)
                    vec3 norm( _q * fastRotate(arrowAxis, *itNorm++));
#endif
                    for(int h=0; h<3; h++) {
                        vec3 coord(*itVtx++ * resizeAxes); //  reduction
                    // reposition starting point...
                        if(!skipCone && coord.x >  0)                          coord.x = -arrowStartingPoint; 
                        if((skipCone && coord.x <= 0) || 
                           (!showFullAxes && (coord.x < arrowStartingPoint)) ) coord.x =  arrowStartingPoint;
                    //transform
                        coord = _q * fastRotate(arrowAxis, coord); 
                        uv[h] = normalizeToControlSize(coord.x,coord.y);
#ifdef imguiGizmo_INTERPOLATE_NORMALS
                        vec3 norm( _q * fastRotate(arrowAxis, *itNorm++));
#endif
                        //col[h] = addLightEffect(ImU32(0xFF) << arrowAxis*8, float(0xa0)*norm.z+.5f);
                        col[h] = addLightEffect(vec4(float(arrowAxis==axisIsX),float(arrowAxis==axisIsY),float(arrowAxis==axisIsZ), 1.0), norm.z, coord.z);
                    }
                    addTriangle();
                }
            }
        }
    };

    //////////////////////////////////////////////////////////////////
    auto drawComponent = [&] (const int idx, const quat &q, ptrFunc func)
    {
        auto *ptrVtx = arrowVtx+idx;
        draw_list->PrimReserve(ptrVtx->size(), ptrVtx->size()); // reserve vtx
        for(auto itVtx = ptrVtx->begin(), itNorm = (arrowNorm+idx)->begin(); itVtx != ptrVtx->end(); ) { 
#if !defined(imguiGizmo_INTERPOLATE_NORMALS)
            vec3 norm = (_q * *itNorm++);
#endif
            for(int h=0; h<3; h++) {
                vec3 coord = *itVtx++;
#ifdef imguiGizmo_INTERPOLATE_NORMALS
                vec3 norm = (q * *itNorm++);
#endif
                coord = q * (func(coord) * resizeAxes); // remodelling Directional Arrow (func) and transforms;

                uv[h] = normalizeToControlSize(coord.x,coord.y);
                //col[h] = addLightEffect(color, float(0xa0)*norm.z+.5f);
                col[h] = addLightEffect(vec4(directionColor.x, directionColor.y, directionColor.z, 1.0), norm.z, coord.z>0 ? coord.z : coord.z*.5);
            }
            addTriangle();
        }
    };

    //////////////////////////////////////////////////////////////////
    auto dirArrow = [&] (const quat &q, int mode) 
    {
        vec3 arrowCoord(_q * vec3(1.0f, 0.0f, 0.0f));

        ptrFunc func = (mode & modeDirPlane) ? adjustPlane : adjustDir;

        if(arrowCoord.z <= 0) { for(int i = 0; i <  4; i++) drawComponent(i, q, func); if(mode & modeDirPlane) drawPlane(); }
        else                  { if(mode & modeDirPlane) drawPlane(); for(int i = 3; i >= 0; i--) drawComponent(i, q, func); }
    };
    
    //////////////////////////////////////////////////////////////////
    auto spotArrow = [&] (const quat &q, const float arrowCoordZ) 
    {
        if(arrowCoordZ > 0) { 
            drawComponent(CONE_SURF, q, adjustSpotCone); drawComponent(CONE_CAP , q, adjustSpotCone);
            drawComponent(CYL_SURF , q, adjustSpotCyl ); drawComponent(CYL_CAP  , q, adjustSpotCyl );
        } else {
            drawComponent(CYL_CAP  , q, adjustSpotCyl ); drawComponent(CYL_SURF , q, adjustSpotCyl );
            drawComponent(CONE_CAP , q, adjustSpotCone); drawComponent(CONE_SURF, q, adjustSpotCone);
        }
    };

    //////////////////////////////////////////////////////////////////
    auto draw3DSystem = [&] ()
    {
        drawAxes(backSide);
        if     (axesOriginType & sphereAtOrigin) drawSphere();
        else if(axesOriginType & cubeAtOrigin)   drawCube();
        drawAxes(frontSide);  
    };

#define CENTER_HELPER_X -.85f
#define CENTER_HELPER_Y -.85f
    //////////////////////////////////////////////////////////////////
    auto drawRotationHelper = [&] () {
        const ImVec2 center(normalizeToControlSize(CENTER_HELPER_X, CENTER_HELPER_Y));
        const float radius = returnSizeFromRatio(.05);
        const int nSegments = 12;
        const ImU32 color = (vgMods & vg::evShiftModifier)   ? 0xff0000ff : 
                            (vgMods & vg::evControlModifier) ? 0xff00ff00 : 0xffff0000;

        if(squareSize<100) { // if too small filled circle
            draw_list->AddCircleFilled(center, radius, color, nSegments);
        } else { // draw arc
            const float thickness = squareSize/100.f;  
            const float a_max = (IM_PI * 1.5f) * ((float)nSegments) / (float)nSegments;
            draw_list->PathClear();
            draw_list->PathArcTo(center, radius - 0.5f, 0.0f, a_max, nSegments);
            draw_list->PathStroke(color, false, thickness);
            if(squareSize>150) { // if big enough draw also arrowhead
                const float lenLine = radius*.33f;
                const float thickRadius = radius - thickness*.5;
                draw_list->AddTriangleFilled(ImVec2(center.x-lenLine, center.y-(thickRadius+lenLine)),
                                                ImVec2(center.x+lenLine, center.y- thickRadius),
                                                ImVec2(center.x-lenLine, center.y-(thickRadius-lenLine)),
                                        color);

                draw_list->AddTriangleFilled(ImVec2(center.x+(thickRadius-lenLine), center.y+lenLine),
                                                ImVec2(center.x+ thickRadius         , center.y-lenLine),
                                                ImVec2(center.x+(thickRadius+lenLine), center.y+lenLine),
                                        color);
            }

        }
    };

    //////////////////////////////////////////////////////////////////
    auto drawPanHelper = [&] () {
        const ImVec2 center(normalizeToControlSize(CENTER_HELPER_X, CENTER_HELPER_Y));
        const float lenLine = returnSizeFromRatio(.05f);
        const float halfLen = lenLine * .5f;
        const float hhLen = halfLen * .5f;
        const ImU32 color = 0xffffff00;
                    draw_list->AddTriangleFilled(ImVec2(center.x        , center.y+lenLine+halfLen),
                                                 ImVec2(center.x-halfLen, center.y+lenLine-hhLen  ),
                                                 ImVec2(center.x+halfLen, center.y+lenLine-hhLen  ),
                                            color);
                    draw_list->AddTriangleFilled(ImVec2(center.x        , center.y-lenLine-halfLen),
                                                 ImVec2(center.x-halfLen, center.y-lenLine+hhLen  ),
                                                 ImVec2(center.x+halfLen, center.y-lenLine+hhLen  ),
                                            color);
                    draw_list->AddTriangleFilled(ImVec2(center.x+lenLine+halfLen, center.y        ),
                                                 ImVec2(center.x+lenLine-hhLen  , center.y-halfLen),
                                                 ImVec2(center.x+lenLine-hhLen  , center.y+halfLen),
                                            color);
                    draw_list->AddTriangleFilled(ImVec2(center.x-lenLine-halfLen, center.y        ),
                                                 ImVec2(center.x-lenLine+hhLen  , center.y-halfLen),
                                                 ImVec2(center.x-lenLine+hhLen  , center.y+halfLen),
                                            color);
    };

    //////////////////////////////////////////////////////////////////
    auto drawDollyHelper = [&] () {
        const ImVec2 center(normalizeToControlSize(CENTER_HELPER_X, CENTER_HELPER_Y));
        const float lenLine = returnSizeFromRatio(.05f);
        const float halfLen = lenLine * .5f;
        const ImU32 color = 0xff00ffff;
                    draw_list->AddTriangleFilled(ImVec2(center.x        , center.y+lenLine+halfLen),
                                                 ImVec2(center.x-lenLine, center.y+halfLen        ),
                                                 ImVec2(center.x+lenLine, center.y+halfLen        ),
                                            color);
                    draw_list->AddTriangleFilled(ImVec2(center.x        , center.y-lenLine        ),
                                                 ImVec2(center.x-halfLen, center.y-halfLen        ),
                                                 ImVec2(center.x+halfLen, center.y-halfLen        ),
                                            color);
    };

    //  ... and now..  draw the widget!!!
    ///////////////////////////////////////
    //if((drawMode & modePanDolly) && (ImGui::IsItemHovered() || ImGui::IsMouseDragging(0))) {

    if(drawMode & (modeDirection | modeDirPlane)) dirArrow(_q, drawMode);
    else { // draw arrows & solid
        if(drawMode & modeDual) {
            vec3 spot(qtV2 * vec3(-1.0f, 0.0f, .0f)); // versus opposite
            if(spot.z>0) { draw3DSystem(); spotArrow(normalize(qtV2),spot.z); }
            else         { spotArrow(normalize(qtV2),spot.z); draw3DSystem(); }
        } else draw3DSystem();
    }

    // Helper on vgModifier active
    if(vgModsActive && (ImGui::IsItemHovered() && (!ImGui::IsMouseDown(0) && !ImGui::IsMouseDown(1)) )) {
#ifndef IMGUIZMO_USE_ONLY_ROT
        if(drawMode & modePanDolly) {
            if(panMod & vgMods)        drawPanHelper();
            else if(dollyMod & vgMods) drawDollyHelper();
        } else {
            drawRotationHelper();
        }
#else
        drawRotationHelper();
#endif
    }

    // Draw text from top left corner
    ImGui::SetCursorScreenPos(controlPos);
    if(label[0]!='#' && label[1]!='#') ImGui::Text("%s", label);

    draw_list->PopClipRect();

    ImGui::EndGroup();
    ImGui::PopID();

    return value_changed;
}

//  Polygon
////////////////////////////////////////////////////////////////////////////
void imguiGizmo::buildPolygon(const vec3 &size, ImVector<vec3> &vtx, ImVector<vec3> &norm)
{

    vtx .clear();
    norm.clear(); 

#define V(a,b,c) vtx.push_back(vec3(a size.x, b size.y, c size.z))
#define N(x,y,z) norm.push_back(vec3(x, y, z))

    N( 1.0f, 0.0f, 0.0f); V(+,-,+); V(+,-,-); V(+,+,-); V(+,+,+);
    N( 0.0f, 1.0f, 0.0f); V(+,+,+); V(+,+,-); V(-,+,-); V(-,+,+);
    N( 0.0f, 0.0f, 1.0f); V(+,+,+); V(-,+,+); V(-,-,+); V(+,-,+);
    N(-1.0f, 0.0f, 0.0f); V(-,-,+); V(-,+,+); V(-,+,-); V(-,-,-);
    N( 0.0f,-1.0f, 0.0f); V(-,-,+); V(-,-,-); V(+,-,-); V(+,-,+);
    N( 0.0f, 0.0f,-1.0f); V(-,-,-); V(-,+,-); V(+,+,-); V(+,-,-);

#undef V
#undef N
}
//  Sphere
////////////////////////////////////////////////////////////////////////////
void imguiGizmo::buildSphere(const float radius, const int tessFactor)
{
    const int div       =  tessFactor; //tessellation colors: meridians/div x paralles/div
    const int meridians = 32; //64/2;
    const int parallels = meridians/2;

    sphereVtx .clear();
    sphereTess.clear();

#   define V(x,y,z) sphereVtx.push_back(vec3(x, y, z))
#   define T(t)     sphereTess.push_back(t)
 
    const float incAngle = 2.0f*T_PI/(float)( meridians );
    float angle = incAngle;

    // Adjust z and radius as stacks are drawn.
    float z0, z1 = cosf(angle)*radius;
    float r0, r1 = sinf(angle)*radius;
    float x1 = -1.0f;
    float y1 =  0.0f;

    // The first pole==>parallel is covered with triangles
    for(int j=0; j<meridians; j++, angle+=incAngle) {
        const float x0 = x1; x1 = cosf(T_PI-angle);
        const float y0 = y1; y1 = sinf(T_PI-angle);

        const int tType = ((j>>div)&1);

        V(0.0f,   0.0f, radius); T(tType);
        V(x0*r1,-y0*r1,     z1); T(tType);
        V(x1*r1,-y1*r1,     z1); T(tType);
    }

    // Cover each stack with a quad divided in 2 triangles, except the top and bottom stacks 
    angle = incAngle+incAngle;
    x1 = 1.f; y1 = 0.f;
   
    for(int i=1; i<parallels-1; i++, angle+=incAngle) {
        //int div =8;
        z0 = z1; z1 = cosf(angle)*radius;
        r0 = r1; r1 = sinf(angle)*radius;
        float angleJ = incAngle;

        for(int j=0; j<meridians; j++, angleJ+=incAngle) {
            const float x0 = x1; x1 = cosf(angleJ);
            const float y0 = y1; y1 = sinf(angleJ);

            const int tType = ((i>>div)&1) ? ((j>>div)&1) : !((j>>div)&1); 

            V(x0*r1, -y0*r1, z1); T(tType);
            V(x0*r0, -y0*r0, z0); T(tType);
            V(x1*r0, -y1*r0, z0); T(tType);
            V(x0*r1, -y0*r1, z1); T(tType);
            V(x1*r0, -y1*r0, z0); T(tType);
            V(x1*r1, -y1*r1, z1); T(tType);
        }
    }

    // The last parallel==>pole is covered with triangls
    z0 = z1; 
    r0 = r1;
    x1 = -1.0f; y1 = 0.f;

    angle = incAngle;
    for(int j=0; j<meridians; j++,angle+=incAngle) {
        const float x0 = x1; x1 = cosf(angle+T_PI);
        const float y0 = y1; y1 = sinf(angle+T_PI);

        const int tType = ((parallels-1)>>div)&1 ? ((j>>div)&1) : !((j>>div)&1); 

        V( 0.0f,   0.0f,-radius); T(tType);
        V(x0*r0, -y0*r0,     z0); T(tType);
        V(x1*r0, -y1*r0,     z0); T(tType);
    }
#   undef V
#   undef C
}
//  Cone / Pyramid
////////////////////////////////////////////////////////////////////////////
void imguiGizmo::buildCone(const float x0, const float x1, const float radius, const int slices)
{
    const float height = x1-x0 ;

    // Scaling factors for vertex normals 
    const float sq = sqrtf( height * height + radius * radius );
    const float cosn =  height / sq;
    const float sinn =  radius / sq;

    const float incAngle = 2.0f*T_PI/(float)( slices );
    float angle = incAngle;

    float yt1 = sinn,  y1 = radius;// ==> yt1 = cos(0) * sinn, y1 = cos(0) * radius 
    float zt1 = 0.0f,  z1 = 0.0f;  // ==> zt1 = sin(0) * sinn, z1 = sin(0) * radius 

    const float xt0 = x0 * cosn, xt1 = x1 * cosn; 

    arrowVtx[CONE_CAP ].clear(); arrowNorm[CONE_CAP ].clear();
    arrowVtx[CONE_SURF].clear(); arrowNorm[CONE_SURF].clear();

#   define V(i,x,y,z) arrowVtx [i].push_back(vec3(x, y, z))
#   define N(i,x,y,z) arrowNorm[i].push_back(vec3(x, y, z)) 

    for(int j=0; j<slices; j++, angle+=incAngle)  {   
        const float yt0 = yt1;  yt1 = cosf(angle);
        const float y0  = y1;   y1  = yt1*radius;   yt1*=sinn;
        const float zt0 = zt1;  zt1 = sinf(angle);
        const float z0  = z1;   z1  = zt1*radius;   zt1*=sinn;   

    // Cover the circular base with a triangle fan... 
        V(CONE_CAP,  x0, 0.f, 0.f);
        V(CONE_CAP,  x0,  y0, -z0);
        V(CONE_CAP,  x0,  y1, -z1);

        N(CONE_CAP,-1.f, 0.f, 0.f);
#                                    ifdef imguiGizmo_INTERPOLATE_NORMALS
        N(CONE_CAP,-1.f, 0.f, 0.f);
        N(CONE_CAP,-1.f, 0.f, 0.f);
#endif
        V(CONE_SURF, x1, 0.f, 0.f);
        V(CONE_SURF, x0,  y0,  z0);
        V(CONE_SURF, x0,  y1,  z1);
#                                    ifdef imguiGizmo_INTERPOLATE_NORMALS
        N(CONE_SURF,xt1, 0.f, 0.f);
        N(CONE_SURF,xt0, yt0, zt0);
        N(CONE_SURF,xt0, yt1, zt1);
#else
        N(CONE_SURF, xt0, yt0, zt0);
#endif
    }
#undef V
#undef N
}
//  Cylinder
////////////////////////////////////////////////////////////////////////////
void imguiGizmo::buildCylinder(const float x0, const float x1, const float radius, const int slices)
{

    float y1 = 1.0f, yr1 = radius;
    float z1 = 0.0f, zr1 = 0.0f; // * radius

    const float incAngle = 2.0f*T_PI/(float)( slices );
    float angle = incAngle;

    arrowVtx[CYL_CAP ].clear(); arrowNorm[CYL_CAP ].clear();
    arrowVtx[CYL_SURF].clear(); arrowNorm[CYL_SURF].clear();

#   define V(i,x,y,z) arrowVtx [i].push_back(vec3(x, y, z))
#   define N(i,x,y,z) arrowNorm[i].push_back(vec3(x, y, z)) 

    for(int j=0; j<slices; j++, angle+=incAngle) {
        const float y0  = y1;   y1  = cosf(angle);
        const float z0  = z1;   z1  = sinf(angle);
        const float yr0 = yr1;  yr1 = y1 * radius;
        const float zr0 = zr1;  zr1 = z1 * radius;

    // Cover the base  
        V(CYL_CAP,   x0, 0.f, 0.f);
        V(CYL_CAP,   x0, yr0,-zr0);
        V(CYL_CAP,   x0, yr1,-zr1);

        N(CYL_CAP, -1.f, 0.f, 0.f);
#                                   ifdef imguiGizmo_INTERPOLATE_NORMALS
        N(CYL_CAP, -1.f, 0.f, 0.f);
        N(CYL_CAP, -1.f, 0.f, 0.f);
#endif
    // Cover surface
        N(CYL_SURF, 0.f,  y0,  z0);
        N(CYL_SURF, 0.f,  y0,  z0);
#                                   ifdef imguiGizmo_INTERPOLATE_NORMALS
        N(CYL_SURF, 0.f,  y1,  z1);
        N(CYL_SURF, 0.f,  y0,  z0);
        N(CYL_SURF, 0.f,  y1,  z1);
        N(CYL_SURF, 0.f,  y1,  z1);
#endif
        V(CYL_SURF,  x1, yr0, zr0);
        V(CYL_SURF,  x0, yr0, zr0);
        V(CYL_SURF,  x0, yr1, zr1);
        V(CYL_SURF,  x1, yr0, zr0);
        V(CYL_SURF,  x0, yr1, zr1);
        V(CYL_SURF,  x1, yr1, zr1);
#ifdef SHOW_FULL_CYLINDER 
    // Cover the top ..in the arrow this cap is covered from cone/pyramid
        V(CYL_CAP ,  x1, 0.f, 0.f);
        V(CYL_CAP ,  x1, yr0, zr0);
        V(CYL_CAP ,  x1, yr1, zr1);
        N(CYL_CAP , 1.f, 0.f, 0.f);
    #                               ifdef imguiGizmo_INTERPOLATE_NORMALS
        N(CYL_CAP , 1.f, 0.f, 0.f);
        N(CYL_CAP , 1.f, 0.f, 0.f);
    #endif
#endif
    }
#undef V
#undef N
}





