## bloom 
 需求: 
    main_quque,增加 render_buffers[RGBA16F]，或 render_buffers[1]原图，
    但高频信息将会丢失模糊，当前手机普遍支持RGBA16F,最好使用
 实现:
   1.提供 blur_size,strength,spread,iters 等控制参数，可由界面使用设置，选择效果
   2.针对移动，可选择迭代次数，在1/2 framesize 情况下，1-2次iters即可，多数配合
     size,strength 1 次iters 即可.
经验参数：
   blur_size = 5
   strength = 3.25
   spread = 1 
   iters = 2      
## package
  已经打包到 ant.image_effect 作为一个后期字系统，使用者只需要在工程种 ecs.import "ant.image_effect" ，即可使用
  image_effect 作为后期包，通过新加其他 post system 即可扩充.

# boom 目录下的shader，material 已经迁移到 ant.resource 目录


