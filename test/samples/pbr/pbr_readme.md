### 实现两种工作流
    metallic flow/specular flow   区别在于 smooth/groughness的控制，以那种为主制作,简化使用难度，指定一种即可
                                  u_params[0] = 0 ,默认为 metallic flow
                               
 
### 相关参数 
    u_params[]                    [0] metallic/specular flow,  default =0(metallic);
                                  [1] metallic/rough control value mode, >=1 float value mode(default), <1 = tex mode 
                                  [2] metallic value (0-1) 
                                  [3] roughness value (0-1)
    basecolor                     颜色 ：基本控制颜色，可以对像素颜色进行二次着色控制，达到一张基本纹理，多种效果的目的
    albeldo                       纹理1：基本纹理，提供无阴影明暗的基本像素颜色
    normal                        纹理2: 正常的 normalmap
    metallic                      数值u_params[2]，或 纹理Opt1[可选]，sh
      value or tex                2选1，效率和效果平衡，使用 value 控制效果就很不多，适合移动设备    
                                  u_params[1] = 0
    roughness                     数值u_params[3]  
      value                       当需要使用tex 时，可以和 metallic 合并，减少采样成本

    texCube                       纹理3： Radiant quantity
    texCubeIrr                    纹理Opt2：Radiant flux,可简化省略

    其中纹理1-3，必备，纹理Opt1-2 可选，根据不同目标平台和效果选择，一般控制在3个纹理即可达不错视觉效果。

    
### 应用
    gold.material                  定义 gold 类型的常规参数,颜色，金属，粗糙度，形成一个固定的pbr 类型材质
    plastic.material               定义塑料相关,
    其余类型类似，以此形成常用几个主题类型




