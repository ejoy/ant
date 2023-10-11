关于原始资源编译
================

资源编译结果放在项目的特定目录 .build 下：

.build 目录按文件类型、平台编译配置、文件名做三层结构，保存实际的编译目标文件。

以 foo.texture 为例：

我们有一个 /path/foo.texture 的原始文件，编译过程会

1. 根据它的编译参数生成一个配置串叫做 HASH ，其中 HASH 为配置文件的 sha1 值的前 7 个字母。同时，该目录下应该存放完整的配置文件 .setting
2. 根据其路径 /path 及文件名，生成一个目标路径名为 foo_PATHHASH ，其中 PATHHASH 为 sha1("/path") 。

最终，编译结果的会放在：

> /.build/texture/HASH/foo_PATHHASH/
