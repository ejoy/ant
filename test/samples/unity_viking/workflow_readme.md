### 重构增强，提供 metalness，specular 两个独立的工作流shader
   其中 metalness 提供兼容使用 specular 材质的方法

### 测试两种工作流效果，简化差别后的存放目录
  shader 计算内容不同，材质参数有不同细节。  
  metalness：
     shader     fs_mesh_pbr_metal.sc
     materials  materials_metal
  specular:
     shader     fs_mesh_pbr_spec.sc
     materials  materials_spec
    

##当前默认打开的是 metal，要测试 specular 时，
  将 fs_mesh_pbr_spec.sc 文件名复制转成  fs_mesh_pbr_spec.sc
  将 materials_spec 目录名复制转成 materials  默认名字即可

###注意将转换的目录或文件名做好对应备份,避免不小心覆盖:
   如  materials_ant, materials_spec

  

        

 