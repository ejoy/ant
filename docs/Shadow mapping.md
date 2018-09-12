Shadow mapping
===============================
翻译日期: fangcun 2018-9-12
原文:http://www.opengl-tutorial.org/cn/intermediate-tutorials/tutorial-16-shadow-mapping/

Shadow map是现在(2016)流行的一种生成动态阴影的方法。它很容易实现，但又非常容易实现错误。

在本教程，我们首先介绍Shadow map的一个基础算法，然后分析这个基础算法的缺陷，之后我们介绍一些技巧来获得更好的效果。
由于Shadow map的研究现在还十分火热(2012年)，我们在最后还给出一些可以提升效果的方向。

基础Shadowmap算法
-----------------------------

基础Shadowmap算法包含两步。
(1)在光源处，沿光照方向渲染场景，计算出每个像素深度值。
(2)在正常的渲染中测试像素是否在阴影中。

判断像素是否在阴影中的算法如下：
(1)如果像素的深度值大于Shadowmap中同一位置像素的深度值，说明这个像素处在阴影中。

下图解释了这一原理：

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/shadowmapping.png)

渲染shadowmap
------------------------

在本教程，我们只考虑方向光(光源位于无限远处的平行光)。所以我们只需要使用正交投影矩阵就可以渲染我们的shadowmap。
正交投影矩阵不会因为视景体中物体的远近而改变物体的大小。

设置渲染目标和模型视图投影矩阵
---------------------------------------------

我们使用1024x1024的16位的深度纹理来存储shadowmap。通常对于shadowmap来说，16位是足够的。
尝试其它数字也可能取得不错的效果。由于我们需要之后在着色器中对它进行采样，所以我们使用的是深度纹理,
而不是渲染缓冲区(renderbuffer)。

       / The framebuffer, which regroups 0, 1, or more textures, and 0 or 1 depth buffer.
        GLuint FramebufferName = 0;
        glGenFramebuffers(1, &FramebufferName);
        glBindFramebuffer(GL_FRAMEBUFFER, FramebufferName);

       // Depth texture. Slower than a depth buffer, but you can sample it later in your shader
        GLuint depthTexture;
        glGenTextures(1, &depthTexture);
        glBindTexture(GL_TEXTURE_2D, depthTexture);
        glTexImage2D(GL_TEXTURE_2D, 0,GL_DEPTH_COMPONENT16, 1024, 1024, 0,GL_DEPTH_COMPONENT, GL_FLOAT, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, depthTexture, 0);

        glDrawBuffer(GL_NONE); // No color buffer is drawn to.

        // Always check that our framebuffer is ok
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        return false;
 
 用于在光源处进行渲染的模型视图投影矩阵的计算方法如下：
 (1)我们使用正交投影矩阵，它包含了X(-10,10),Y(-10,10),Z(-10,20)空间的场景。
 (2)使用视图矩阵旋转世界空间，使光源方向为-Z方向。
 (3)模型矩阵的设置完全自由。
 
      glm::vec3 lightInvDir = glm::vec3(0.5f,2,2);

      // Compute the MVP matrix from the light's point of view
      glm::mat4 depthProjectionMatrix = glm::ortho<float>(-10,10,-10,10,-10,20);
      glm::mat4 depthViewMatrix = glm::lookAt(lightInvDir, glm::vec3(0,0,0), glm::vec3(0,1,0));
      glm::mat4 depthModelMatrix = glm::mat4(1.0);
      glm::mat4 depthMVP = depthProjectionMatrix * depthViewMatrix * depthModelMatrix;

      // Send our transformation to the currently bound shader,
      // in the "MVP" uniform
      glUniformMatrix4fv(depthMatrixID, 1, GL_FALSE, &depthMVP[0][0]);
 
 着色器
 -------------
 
 我们在第一次渲染中使用的顶点着色器非常简单。顶点着色器仅仅计算了顶点变换后的齐次坐标。
 
    #version 330 core

    // Input vertex data, different for all executions of this shader.
    layout(location = 0) in vec3 vertexPosition_modelspace;

    // Values that stay constant for the whole mesh.
    uniform mat4 depthMVP;

     void main(){
         gl_Position =  depthMVP * vec4(vertexPosition_modelspace,1);
      }

像素着色器也同样简单。仅仅在位置0处写入了像素的深度值。

      #version 330 core

      // Ouput data
      layout(location = 0) out float fragmentdepth;

      void main(){
         // Not really needed, OpenGL does it anyway
         fragmentdepth = gl_FragCoord.z;
      }

因为我们对写入的深度值精度要求不高，通常渲染shadowmap要比正常的渲染快两倍。通常对于GPU来说，带宽是性能瓶颈所在。

结果
-----------

渲染后的纹理看起来像这样子:
![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/DepthTexture.png)

颜色越深表示深度值越小。也就是说对于这个shadowmap右上角更接近相机。与之相反，白色意味着深度值为1(齐次坐标下)，
距离相机远。


使用shadowmap
-----------------

基础着色器
-----------

现在，我们回过头来看我们的着色器。我们需要对每一个像素进行计算，看它是否在我们的阴影中。

我们需要计算像素在shadowmap中的位置。这需要进行两次坐标变换。
(1)进行正常的模型视图投影变换。
(2)使用深度模型视图投影变换。

这里有一个小技巧。深度模型视图投影矩阵乘以顶点坐标会产生一个齐次坐标，它的范围是[-1,1]，
但纹理采样必须在[0,1]之间进行。

比如，位于屏幕中心的像素的齐次坐标为(0,0)，它应该采样的纹理坐标为(0.5,0.5)。

我们显然可以在像素着色器中对它进行处理，但使用下面的矩阵乘以这个齐次坐标更加高效。这个矩阵可以把坐标的大小
除以2(对角线[-1,1]变为[-0.5,0.5])，然后转换它们(矩阵最后一行,[-0.5,0.5]变为[0,1])。

      glm::mat4 biasMatrix(
        0.5, 0.0, 0.0, 0.0,
        0.0, 0.5, 0.0, 0.0,
        0.0, 0.0, 0.5, 0.0,
        0.5, 0.5, 0.5, 1.0
       );
      glm::mat4 depthBiasMVP = biasMatrix*depthMVP;

现在我们可以编写顶点着色器了。这次它输出了两个位置信息。

(1)gl_Position是顶点在当前相机中的位置。
(2)ShadowCoord是顶点在光源相机中的位置。

    // Output position of the vertex, in clip space : MVP * position
     gl_Position =  MVP * vec4(vertexPosition_modelspace,1);

    // Same, but with the light's view matrix
     ShadowCoord = DepthBiasMVP * vec4(vertexPosition_modelspace,1);

像素着色器也还是非常简单：
(1)texture( shadowMap, ShadowCoord.xy ).z是光源到最近的遮挡物的距离。
(2)ShadowCoord.z是光源和当前像素之间的距离。

所以如果当前像素离光源更远，它就在阴影中(准确说，在最近的遮挡物的阴影中)。

    float visibility = 1.0;
     if ( texture( shadowMap, ShadowCoord.xy ).z  <  ShadowCoord.z){
       visibility = 0.5;
     }

我们使用这一知识来修改我们的着色器。我们没有修改环境光，因为它的目的是为我们提供
入射光，我们的阴影也能接收到它。(否则，可能得到的结果是一片漆黑。)

      color =
      // Ambient : simulates indirect lighting
      MaterialAmbientColor +
      // Diffuse : "color" of the object
      visibility * MaterialDiffuseColor * LightColor * LightPower * cosTheta+
      // Specular : reflective highlight, like a mirror
      visibility * MaterialSpecularColor * LightColor * LightPower * pow(cosAlpha,5);
 
结果-阴影粉刺(Shadow acne)
-----------------------------
 
下图是我们当前的代码渲染的结果。显而易见，这个效果是无法接受的。
![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/1rstTry.png)
 
让我们来分析出现的问题。我们提供了两个不同的代码:shadowmaps和shadowmaps_simple，你
可以自由选择使用哪一个。shadowmaps_simple的渲染的效果像上图一样简陋，但是更容易理解。
 
问题
------------
 
阴影粉刺
------------
 
最明显的问题是阴影粉刺。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/ShadowAcne.png)
 
这一现象的解释可以看下图：

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/shadow-acne.png)
 
最常用的修正这一问题的方法是添加额外的容错边缘：我们只对在光源空间下深度值比lightmap值远的像素进行着色，
我们添加了bias来实现容错边缘

      float bias = 0.005;
      float visibility = 1.0;
      if ( texture( shadowMap, ShadowCoord.xy ).z  <  ShadowCoord.z-bias){
          visibility = 0.5;
      }

现在渲染的效果好了很多。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/FixedBias.png)

然而，我们又发现，容错边缘造成地面和墙之间的假象尤为明显。更确切地说，0.005大小的容错边缘对于地面
来说太大了，但对于曲面来说又有点小了：在圆柱体和球体上可以看到部分假象。

一个常见的方法是根据斜率设置容错边缘:

       float bias = 0.005*tan(acos(cosTheta)); // cosTheta is dot( n,l ), clamped between 0 and 1
       bias = clamp(bias, 0,0.01);

现在连曲面上的阴影粉刺也没有了。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/VariableBias.png)

这里是另一个技巧，工作与否取决于我们使用的几何体，我们只在shadowmap渲染背面。这种方法要求我们必须使用
一个特殊的集合体(彼得平移(Peter Panning))，以及一个厚厚的墙，但这样做可以使粉刺只出现在阴影之下的表面中，也
就不会被我们看到。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/shadowmapping-backfaces.png)

渲染shadowmap时，剔除三角形正面：

       // We don't use bias in the shader, but instead we draw back faces,
       // which are already separated from the front faces by a small distance
       // (if your geometry is made this way)
       glCullFace(GL_FRONT); // Cull front-facing triangles -> draw only back-facing triangles

渲染场景时我们开启背面剔除。

       glCullFace(GL_BACK); // Cull back-facing triangles -> draw only front-facing triangles

除了容错边缘，我们的代码中也使用了这一方法。

彼得平移(Peter Panning)
---------------------------

现在已经没有阴影粉刺了，但是我们对地面的着色仍然存在问题，看上去我们的墙像飞出去一样(这一现象被叫做 彼得平移).
实际上这一现象很大程度上是由我们添加的容错边缘造成的。

这一现象很容易避免：不适用窄的几何体即可。下面是它的两个优点:
(1)它解决了彼得平移(Peter Panning):设置的几何体要比我们的几何边缘都要厚。
(2)渲染lightmap时我们可以开启背面剔除，墙体面向光源的部分构成了一个的多边形挡住了其它部分，这些部分在背面剔除
开启后不需要渲染。

这个方法的缺点是我们需要渲染更多的三角形(每一帧多渲染一倍！)。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/NoPeterPanning.png)

锯齿
--------

尽管我们使用了两个小技巧，但在阴影的边缘还是存在锯齿。换句话说就是临近的两个像素颜色变化过大，没有平滑过渡。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/Aliasing.png)

PCF
---------

一个最简单的改善锯齿现象的方法是改变shadowmap的采样类型为sampler2DShadow。
这样设置后，当我们采样shadowmap时，实际上也采样了邻近的纹理，然后对它们进行比较，根据比较结果返回
一个范围为[0,1]的双线性过滤的值。

举个例子，0.5意味着2个样本来自阴影，2个样本来自光源。

和对深度值进行的单点采样不同(结果只有true或false),PCF使用4个布尔量来决定最后的结果为true还是false。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/PCF_1tap.png)

就像我们看到的，阴影边缘变得光滑了，但还是有明显的锯齿。

泊松采样（Poisson Sampling)
---------------------------------

一个简单解决方法是对shadowmap进行多次采样。结合PCF后，即使采样次数不多，也可以获得非常好的效果。

下面的代码进行了4次采样:

      for (int i=0;i<4;i++){
         if ( texture( shadowMap, ShadowCoord.xy + poissonDisk[i]/700.0 ).z  <  ShadowCoord.z-bias ){
            visibility-=0.2;
         }
      }

poissonDisk是一个常量数组，它的定义如下:

      vec2 poissonDisk[4] = vec2[](
         vec2( -0.94201624, -0.39906216 ),
         vec2( 0.94558609, -0.76890725 ),
         vec2( -0.094184101, -0.92938870 ),
         vec2( 0.34495938, 0.29387760 )
      );

使用这种方法后，产生的像素可能会因为采样次数的不同变得更黑或更浅:

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/SoftShadows.png)

常量值700.0定义了有多少样本被传播。传播的样本如果很少的话，我们可能最后还是会看到锯齿，太多的话就会出现条带。
(截图中的程序没有使用PCF，但使用了16个样本进行采样)

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/SoftShadows_Close.png)

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/SoftShadows_Wide.png)

分层泊松采样(Stratified Poisson Sampling)
-------------------------------------------

我们可以通过为每一个像素选择不同的样本来避免条带。有两个主要的方法:分层泊松和轮换泊松。
分层会选择不同的样本；旋转则总是选择同一个样本，但是使用了一个随机的轮换，让他们看起来不同。
本教程中我们直接是分层的版本。

和前一版本的唯一不同是我们使用了一个随机索引来索引poissonDisk。

    for (int i=0;i<4;i++){
        int index = // A random number between 0 and 15, different for each pixel (and each i !)
        visibility -= 0.2*(1.0-texture( shadowMap, vec3(ShadowCoord.xy + poissonDisk[index]/700.0,  (ShadowCoord.z-bias)/ShadowCoord.w) ));
     }

我们可以通过下面的代码来产生随机数，它会返回一个范围在[0,1]的随机数：

    float dot_product = dot(seed4, vec4(12.9898,78.233,45.164,94.673));
    return fract(sin(dot_product) * 43758.5453);
    
在我们的例子中，seed4是i的一个组合(也就是说我们采样了4个不同的位置)和其它一些东西:)。我们可以使用
gl_FragCoord(像素在屏幕中的位置)和Position_worldspace。

        //  - A random sample, based on the pixel's screen location.
        //    No banding, but the shadow moves with the camera, which looks weird.
        int index = int(16.0*random(gl_FragCoord.xyy, i))%16;
        //  - A random sample, based on the pixel's position in world space.
        //    The position is rounded to the millimeter to avoid too much aliasing
        //int index = int(16.0*random(floor(Position_worldspace.xyz*1000.0), i))%16;

现在条带消失了，代价是出现了可见的噪点。不过相对而言，处理较好的噪点要比条带好的多。

![img](http://www.opengl-tutorial.org/assets/images/tuto-16-shadow-mapping/PCF_stratified_4tap.png)

更深入的研究
---------------

除了这些技巧，还有非常多的方法可以提升我们的阴影效果，下面是一些最常见的方法。

预测(Early bailing)
----------------------------

相对于为每个像素使用16个样本，我们可以使用4个距离最远的样本。如果它们都在光照下或阴影中，大概率所有16个样本
会得到同样的结果。如果它们不同，大概率像素处在阴影边缘，这时可以进行16个样本的采样。

聚光灯
-------------------

处理聚光灯只需要很少的修改。首先我们需要把正交投影矩阵换成透视投影矩阵:

      glm::vec3 lightPos(5, 20, 20);
      glm::mat4 depthProjectionMatrix = glm::perspective<float>(glm::radians(45.0f), 1.0f, 2.0f, 50.0f);
      glm::mat4 depthViewMatrix = glm::lookAt(lightPos, lightPos-lightInvDir, glm::vec3(0,1,0));

和之前一样，只是把正交投影的视锥体变成了透视投影的视锥体。我们需要使用texture2Dproj来确保透视除法的正确。

我们还需要注意着色器中的透视投影(透视投影矩阵实际上并不进行透视处理。这个处理是由硬件将投影坐标处以w完成的)
在这里我们在着色器中模拟这一处理，所以我们必须自己进行透视除法。如果使用正交投影矩阵的话，是不需要这个操作的，
正交投影矩阵总是产生w=1的齐次坐标。

有两种方法在GLSL中进行这个操作。第2种是使用GLSL内建的textureProj，两种方法的结果是一样的。

      if ( texture( shadowMap, (ShadowCoord.xy/ShadowCoord.w) ).z  <  (ShadowCoord.z-bias)/ShadowCoord.w )
      if ( textureProj( shadowMap, ShadowCoord.xyw ).z  <  (ShadowCoord.z-bias)/ShadowCoord.w )

点光源
---------------

同样的做法，但是使用深度立方体贴图。立方体贴图是6个纹理的几何，立方体的每一个面上有一个纹理。它不能通过
标准的UV纹理坐标来访问，但可以使用一个三维向量表示方向。

空间所有方向的深度值都被存储，使得围绕点光源的阴影计算成为可能。

多个光源
--------------------

这个算法可以处理多个光源，但要对每个光源计算shadowmap。这可能需要大量的内存，可能很快就达到带宽瓶颈。

自动光锥体
---------------

在本教程中，光锥体被我们手动设置包含了整个场景，但这样做仅仅对示例工作，应该避免这样。如果我们的
地图大小是1Km x 1Km，1024x1024的shadowmap的每一个单元就会表示1平方米，这样的结果是很可笑的。光源的
投影矩阵应该尽可能覆盖的场景范围应该尽可能小。

对于聚光灯，可以调节它覆盖的范围。
对于平行光，比如太阳，就需要一些技巧来处理：它们确实需要照亮整个场景。下面是一个计算光锥的方法：
(1)潜在阴影接收体或PSRs在同一时间处于光锥体，视景体和场景包围盒里的物体。
(2)潜在的阴影产生者或PCFs都是潜在的阴影接收者，以及处于这些物体和光源之间的物体。(一个不可见物体也可能产生一个阴影)

因此，在计算光源投影矩阵时，我们可以删去离光源很远的一部分可见物体，然后计算剩余物体的包围盒，然后加上处于
光源和包围盒之间的物体，计算新的包围盒(但这一次，沿着光源方向构造)

更精确的方法是计算它们的凸包，但这个方法更容易实现。

这个方法在物体从视景体消失时可能会产生突然的抖动，这是由于shadowmap的分辨率突然增加。 
层叠Shadowmap(Cascaded Shadow Maps)不存在这个问题，但CSM的实现要困难一些，并且我们可以通过平滑过渡来
克服这个问题。

指数shadowmap(Exponential shadow maps)
----------------------------------------

指数shadowmap通过假设一个在阴影中，但接近光表面的像素来减少锯齿。它和容错边缘类似，除了它的测试结果不是布尔量：
像素会变得越来越暗随着他照亮的表面增加。

这是明显的作弊手段，当两个物体重叠时会产生假象。

光照空间透视shadowmap(Light-space perspective Shadow Maps)
--------------------------------------------------------------

LiSPSM通过调节投影矩阵来使近处物体拥有更高的精度。
这在"狭路相逢"这种情况下会得到很好的效果，你望着一个方向，对面同时有一个聚光灯打向你。
在光源近处你会得到更精细的shadowmap，但距离你的位置较远:),在相机近处你最需要的地方(对于狭路相逢而言)拥有较低的精度。

然而LiSPSM的实现很具有技巧性，实现起来相对困难。

层叠shadowmap(Cascaded Shadow Maps)
-------------------------------------

CSM可以解决比LiSAPSM更多的问题，但是使用的方法是不同的。它简单的通过视景体不同部分的(2-4)个标准shadowmap来进行
工作。第一个处理很小的空间，所以，我们可以拥有极高的分辨率。下一个处理远一些的物体，最后一个shadowmap处理
场景的很大一部分，由于透视的原因，远处空间的远远不如近处重要。

CSM到目前为止拥有最佳的复杂度/质量平衡(2012年)，它目前被大量使用。

总结
------------

如你所料，shadowmap是一个复杂的课题。每一年都有新的改进被发表，到目前位置，还不存在完美的方案。

幸运的是，这些方法大多数都可以组合在一起使用:比如可以在光源视景体使用Cascaded Shadow Maps，然后在
使用PCF进行抗锯齿。可以尝试这些技术找出相对最好的组合方案。

最后，建议尽量使用预先计算的lightmap，而只对动态物体使用shadowmaps，还要确保两者的质量相差不多：
毕竟一个非常完美的静态环境和一个丑陋的动态阴影在一起很不搭配:)

