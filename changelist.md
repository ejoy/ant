  记录一下在苹果环境下编译可能会需要做的修改
  目前只针对fileserver系统，所以没有所有都编，以后可能会增加
  
  - 使用到的库将会采用静态链接，所以需要编译出.a的文件；另外编译的架构需要考虑一下是针对ios的arm64位而不是x86这些，这里提供xcode下的工程可以进行编译
  - 由于ios11取消了system方法，在loslib.c中的os_execute中会有对system的调用会报错，网上方法是用ntfw，这块暂时还是不很理解意思，找了一个网上的方法解决：https://blog.csdn.net/wangwenfei1990/article/details/78122134
  - winfile在mac/ios下不可用，这里暂时替换为原生的lfs，后面再做封装
  - 苦使用静态链接，需要在C代码部分使用luaL_requiref（）把库加载到package.loaded里面当中，在这之前需要声明一下各个模块的luaopen接口，如luaopen__crypt
  - **lanes不需要直接调用requiref，因为他自己包含了一个luaopen_lanes_embedded（）函数，这个接口里面调用了requiref，另外需要提供函数运行lanes.lua的代码**
  - lanes这块比较麻烦的是在gen另外一个线程的时候，package信息并不会完全拷贝过去，只有path，cpath，preload，loaders以及searchers。package.loaded中的模块由于我们这里用了C函数直接加载，新的lanes无法获取相应的信息。在生成新的lanes的时候通过globals传过去会找不到destination function，似乎是只有函数名称的table，而这个table无法映射到实际模块的意思。经过网上的调查后，目前使用的解决方法是通过C代码编写一个函数给lanes.configure的on_state_create，这个函数会将luaopen_crypt这些函数加到package.preload里面，这样在另外的线程中才可以实现调用。 