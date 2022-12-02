#### 架构
1. RT需要使用FrameGraph的形式进行修改。目前postprocess尤其需要这个修改进行不同pass的引用；
2. 使用DeferredShading。目前的one pass deferred能够很好解决deferrd shading占用过多带宽的问题；

#### Bug
1. 修复引擎在D3D12/Vulkan中的问题；
2. 修复bloom后处理，在emissive color值很高的时候，依然没有bloom的效果。具体使用furnace-1.glb这个文件用于测试；(2022.11.08已经完成)

#### 优化：
1. 顶点压缩。
  1)使用四元数多normal/tangent/bitangent进行压缩；(2022.11.08已经完成)
  2)使用更多的16bit的顶点数据，以更大程度上压缩顶点占用的数量；
2. 着色器优化。尽可能使用mediump和lowp格式。目前默认全部都是highp格式；
3. 后处理优化
  1) Bloom目前的效果并不好；(2022.11.08已经完成)
  2) 后处理的DoF是时候要解决了。bgfx里面有一个one pass的DoF例子，非常值得参考；
  3) Color Grading需要用于调整颜色；
  4) tonemapping能够预先bake到一张贴图里面，而不需要单独在fragment阶段进行计算。具体要看filament里面的tonemapping的操作；
3. 水渲染；
4. 优化阴影，主要还是提高精度；//2022.09.29已经完成
5. 使用FXAA/TAA，解决bgfx在MSAA下，不同平台直接很多bug的问题。(2022.11.08已经完成)
6. ibl的计算应该直接烘培，不应该做在compute shader上；
7. 使用Hi-Z的方式进行剔除；
8. 使用compute shader将MSAA的深度resolve到普通的深度；(2022.11.08已经完成。但不同的机器resolve msaa的depth硬件不一定支持)
9. 增强阴影的效果，使用VSM实现软阴影，或对比使用PCF的效果；(2022.11.08已经完成)
10. 对相同材质的物体进行排序渲染，目前渲染顺序的提交，都是按照提交的先后次序来的。还需要单独对alpha test的物体进行分类（分类的队列顺序应该为：opaque->alpha test-> translucent）。而对于translucent的物体来讲，还需要根据从远到近的排序来渲染（避免alpha blend错误）；
11. 顶点数据使用不同的流。目前所有顶点都打包到一个流里面，当某个着色器不会访问到对应的顶点数据的时候，相应的带宽就会被浪费掉了。但目前代码很多地方都依赖着只有一个流的逻辑，多个流的情况是否真的能够提交性能还需要验证；
12. 考虑一下把所有的光照计算都放在view space下面进行计算。带来的好处是，u_eyePos/v_distanceVS/v_posWS这些数据都不需要占用varying，都能够通过gl_FragCoord反算回来（某些算法一定需要做这种计算）；
13. 渲染遍历在场景没有任何变化的时候，直接用上一帧的数据进行提交，而不是现在每一帧都在遍历；
14. AO效果和效率的优化。效果：修复bent_normal和cone tracing的bug；效率：使用hi-z提高深度图的采样（主要是采样更低的mipmap，提高缓存效率）；
15. 在转换到新一代图形API后（Metal/Vulkan/D3D12），需要对render pass进行优化。如postprocess里面，如果一个framebuffer的输出是另一个pass的输入，需要使用到subpass的概念进行优化，这能够省掉不少贷款（因为下一个pass的输入，并不会真的写道framebuffer身上）；
16. 优化bgfx的draw viewid和compute shader viewid；

#### 新功能/探索
1. 天气系统。让目前游戏能够昼夜变化。一个简单的方式是使用后处理的color grading改变色调，另外一个更正确的方法应该是使用动态的天空盒；
2. SDF Shadow；
3. Visibility Buffer；
4. GI相关。SSGI，SSR和SDFGI等；
5. LOD；
6. 阴影的VSM；  //2022.09.29已经完成。
7. 这个功能，很可能就会要求引擎需要延迟渲染的，one pass deferred在很多硬件上面是可行的；

#### 增强调试功能
1. 影子。只管的在屏幕上看到对应的shadowmap、csm frustum等；
2. 添加一个overdraw的模式，观察哪些像素是背多次渲染了。详细参考unity和虚幻上的做法；



