关于原始资源编译
================

资源编译结果放在项目的特定目录 _build 下：

_build 目录按文件类型、平台编译配置、文件名做三层结构，保存实际的编译目标文件。

由于编译目标文件可以有多个，所以是一个目录，目录中一定有一个 main.index 文件作为总的索引。

以 foo.shader 为例：

我们有一个 /path/foo.shader 的原始文件，编译过程会

1. 根据它的编译参数以及平台名称（例如 win）生成一个配置串叫做 win_HASH ，其中 HASH 为配置文件的 sha1 值的前 7 个字母。同时，该目录下应该存放完整的配置文件 .config 。
2. 根据其路径 /path 及文件名，生成一个目标路径名为 foo_PATHHASH ，其中 PATHHASH 为 sha1("/path") 。

最终，编译目标的索引会放在：

> /_build/shader/win_HASH/foo_PATHHASH/main.index

其余文件会放在同一目录下。

其中 `/_build/shader/win_HASH/.config` 是该目录下所有文件共有的编译配置文件。
而 `/_build/shader/win_HASH/foo_PATHHASH/.config` 则是对该目录的描述（下面解释）。

由于 PATHHASH 值往往过长，大多数情况下，我们并不需要太长的 HASH 防止冲突，所以，我们一开始只取 sha1 的前四个字母。当发生冲突的时候，增加一个字母的 PATHHASH ，直到不出现冲突。

同时，保存一个 .config 文件记录完整的目录名。

一个 .config 大概是这样：

```
fullname : /path/foo.shader
```