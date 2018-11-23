# Bgfx文件格式

---

Bgfx文件根据读取的类型分为几个模块
- BGFX_CHUNK_MAGIC_VB: Vertex Buffer
- BGFX_CHUNK_MAGIC_IB: Index Buffer
- BGFX_CHUNK_MAGIC_IBC: Index Buffer Compressed
- BGFX_CHUNK_MAGIC_PRI: Primitive Data
- ....
还有很多,结构也可以自己定义,这几个常用的定义可在*bgfx_utils.cpp*中找到

每次读取前都会**先读取一个四字节的CHUNK**来判断后面读取数据的类型,下面介绍上面四个模块读取的数据结构(不包括确定类型的四字节CHUNK).
**下面结构都可以在bgfx_utils.cpp中找到**

- BGFX_CHUNK_MAGIC_VB
  + 包围球, 结构Sphere
  + AABB, 结构Aabb
  + OBB, 结构Obb
  + 顶点描述**decl**, 结构bgfx::VertexDecl(在后面会具体介绍)
  + 顶点个数
  + 顶点data(单个顶点字节大小可从decl中的得到)
  + 通过这个数据,可创建Vertex Buffer(bgfx::createVertexBuffer)

- BGFX_CHUNK_MAGIC_IB
  + 索引个数
  + 索引data(索引数据类型是uint16_t, 或者其他大小为2的数据, 可自定义)
  + 通过这个可以创建Index Buffer(bgfx::createIndexBuffer)

- BGFX_CHUNK_MAGIC_IBC
  + 索引个数
  + 压缩索引大小
  + 压缩索引data
  + 通过压缩索引的data可以解压出非压缩索引的data
  + 通过非压缩索引创建Index Buffer

- BGFX_CHUNK_MAGIC_PRI
  + 材质名称长度
  + 材质名称
  + 该材质下primitive的个数
  + for each primitive
      + primitive名称长度
      + primitive名称
      + primitive的起始索引
      + primitive的索引个数
      + 起始顶点
      + 顶点个数
      + 包围球
      + AABB
      + OBB
      + **primitive的索引和顶点对应的是上面传入的vertex和index**

**需要注意的是,primitive目前必须放到vertex和index后面传入,因为目前默认bgfx是以group来管理渲染数据,每个group对应一个vb一个ib以及其他数据,只有在读取到一个BGFX_CHUNK_MAGIC_PRI的数据类型后会把缓存的group放入到管理队列中**
**另外,每个group中默认只有一个vb和一个ib,重复读取vb或者ib而不读取primitive会覆盖掉之前的vb和ib**

## bgfx::VertexDecl格式
VertexDecl用于描述一个顶点的格式
在一个Vertex里面,不仅仅可能包含顶点的位置,还有可能包含顶点的颜色,贴图uv,法线等等,需要通过这个定义

VertexDecl创建之后, 需要在bgfx::VertexDecl::begin()和bgfx::VertexDecl::end()中添加数据类型,示例代码如下:

    bgfx::VertexDecl decl;
    decl.begin();
    decl.add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float);
    decl.add(bgfx::Attrib::Normal, 3, bgfx::AttribType::Float, true, false);
    decl.end();

add的描述为:
    
    VertexDecl& add(Attrib::Enum _attrib
			, uint8_t _num
			, AttribType::Enum _type
			, bool _normalized = false
			, bool _asInt = false);
			
_attrib表示的是该数据的表示的是什么数据,此处表示的是位置, 其他类型还包括Tangent,Bitangent,Color0,TexCoord0等等
_num表示的是该数据几个值为一组,示例的Position是3个数为一组坐标值
_type表示的是数据类型,示例的Position表示该数据是Float类型
_normalized表示的是数据是否需要单位化,主要是方便vertex shader中使用
_asInt主要是用于顶点是否打包(packing)成uint8或者int16,解包(unpacking)代码必须在shader中实现. *没有使用过,具体信息可能不太清楚*
**以上数据结构可以在bgfx.h中找到**

    
    
       



