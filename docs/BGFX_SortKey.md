SortKey说明
==============


本文讲解BGFX源文件中出现的SortKey类型进行说明。

SortKey之前的定义的常量
------------------------

SortKey之前定义了许多常量，这些常量在SortKey被使用，所以我们首先对这些常量进行说明。

我们首先看这几个常量：

    #define SORK_KEY_NUM_BITS_VIEW         10

    #define SORT_KEY_VIEW_SHIFT            (64-SORK_KEY_NUM_BITS_VIEW)
    #define SORT_KEY_VIEW_MASK             ( (uint64_t(BGFX_CONFIG_MAX_VIEWS-1) )<<SORT_KEY_VIEW_SHIFT)

    #define SORT_KEY_DRAW_BIT_SHIFT        (SORT_KEY_VIEW_SHIFT - 1)
    #define SORT_KEY_DRAW_BIT              (UINT64_C(1)<<SORT_KEY_DRAW_BIT_SHIFT)

其中出现了一个没有在这里定义的常量**BGFX_CONFIG_MAX_VIEWS**，它在BGFX中被定义为256(可以注意到到这个数是2的幂，2的幂-1可以得到2进制表示全为1的数字)))。

我们逐个解释这些常量：

首先是
    
    SORK_KEY_NUM_BITS_VIEW                  10


等一下，你没有看错，确实是SORK,:)，也许是写代码的人手抖，反正本人也多次把T,打成K，到底是什么原因，需要询问作者。

从变量名称上看，这个常量表示VIEW所占的**位**的个数，在这里是10。

接着是

    SORT_KEY_VIEW_SHIFT            (64-SORK_KEY_NUM_BITS_VIEW)

这是VIEW的位在整个64位中的偏移，64-**VIEW所占的位数**。

举个例子，假设我们的VIEW位的数据的二进制为**0000001000**，那么它在整个64位中位置需要左移54位。

就像下面这样子：

    0000001000XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

然后是

    SORT_KEY_VIEW_MASK             ( (uint64_t(BGFX_CONFIG_MAX_VIEWS-1) )<<SORT_KEY_VIEW_SHIFT)


前面已经说过**BGFX_CONFIG_MAX_VIEWS**的值被设置位**256**，那么256-1就是255，它的二进制表示是**11111111**，也就是8个**1**。

然后**11111111**被左移了54位，被放在VIEW位的位置，构成了VIEW位的掩码。

就像这个常量的名称一样，**SORT_KEY_VIEW_MASK**就是VIEW位的**掩码**。

接下来是

    SORT_KEY_DRAW_BIT_SHIFT                 (SORT_KEY_VIEW_SHIFT - 1)

从常量名称可以猜出，它是DRAW位的偏移，它的值在这里是**(SORT_KEY_VIEW_SHIFT - 1)**,也就是**53**。

继续

    SORT_KEY_DRAW_BIT                       (UINT64_C(1)<<SORT_KEY_DRAW_BIT_SHIFT)

这里出现了一个**UINT64_C(1)**，它定义如下:

    #define UINT64_C(x)  (x ## ULL)

也就是说**UINT64_C(1)**实际上就是1ULL，然后它左移DRAW的偏移位数，就得到DRAW的位。

现在我们打印出上面常量的所有数据：

        BGFX_CONFIG_MAX_VIEWS:256                       0000000000000000000000000000000000000000000000000000000100000000
        SORK_KEY_NUM_BITS_VIEW:10                       0000000000000000000000000000000000000000000000000000000000001010
        SORT_KEY_VIEW_SHIFT:54                          0000000000000000000000000000000000000000000000000000000000110110
        SORT_KEY_VIEW_MASK:4593671619917905920          0011111111000000000000000000000000000000000000000000000000000000
        SORT_KEY_DRAW_BIT_SHIFT:53                      0000000000000000000000000000000000000000000000000000000000110101
        SORT_KEY_DRAW_BIT:9007199254740992	   	    0000000000100000000000000000000000000000000000000000000000000000


 我们继续分析这些常量

    #define SORT_KEY_NUM_BITS_DRAW_TYPE    2

    #define SORT_KEY_DRAW_TYPE_BIT_SHIFT   (SORT_KEY_DRAW_BIT_SHIFT - SORT_KEY_NUM_BITS_DRAW_TYPE)
    #define SORT_KEY_DRAW_TYPE_MASK        (UINT64_C(3)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)

    #define SORT_KEY_DRAW_TYPE_PROGRAM     (UINT64_C(0)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)
    #define SORT_KEY_DRAW_TYPE_DEPTH       (UINT64_C(1)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)
    #define SORT_KEY_DRAW_TYPE_SEQUENCE    (UINT64_C(2)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)

首先是

    SORT_KEY_NUM_BITS_DRAW_TYPE                 2

从常量名称上看，它表示DRAW类型所占的位数，在这里是2。

然后是

    SORT_KEY_DRAW_TYPE_BIT_SHIFT        (SORT_KEY_DRAW_BIT_SHIFT - SORT_KEY_NUM_BITS_DRAW_TYPE)

从名称上看它是DRAW类型的位偏移。也就是**DRAW的位偏移**-**DRAW的类型所占的位数**。

继续
    SORT_KEY_DRAW_TYPE_MASK             (UINT64_C(3)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)

没什么好说的，它就是DRAW类型的掩码。

接着

    SORT_KEY_DRAW_TYPE_PROGRAM          (UINT64_C(0)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)
    SORT_KEY_DRAW_TYPE_DEPTH            (UINT64_C(1)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)
    SORT_KEY_DRAW_TYPE_SEQUENCE         (UINT64_C(2)<<SORT_KEY_DRAW_TYPE_BIT_SHIFT)

很明显，这些表示DRAW类型。

我们打印出这些常量:

        SORT_KEY_NUNM_BITS_DRAW_TYPE:2                  0000000000000000000000000000000000000000000000000000000000000010
        SORT_KEY_DRAW_TYPE_BIT_SHIFT:51                 0000000000000000000000000000000000000000000000000000000000110011
        SORT_KEY_DRAW_TYPE_PROGRAM:0                    0000000000000000000000000000000000000000000000000000000000000000
        SORT_KEY_DRAW_TYPE_DEPTH:2251799813685248       0000000000001000000000000000000000000000000000000000000000000000
        SORT_KEY_DRAW_TYPE_SEQUENCE:4503599627370496    0000000000010000000000000000000000000000000000000000000000000000


接着分析下一部分的常量:

        #define SORT_KEY_NUM_BITS_TRANS        2

        #define SORT_KEY_DRAW_0_TRANS_SHIFT    (SORT_KEY_DRAW_TYPE_BIT_SHIFT - SORT_KEY_NUM_BITS_TRANS)
        #define SORT_KEY_DRAW_0_TRANS_MASK     (UINT64_C(0x3)<<SORT_KEY_DRAW_0_TRANS_SHIFT)

        #define SORT_KEY_DRAW_0_PROGRAM_SHIFT  (SORT_KEY_DRAW_0_TRANS_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM)
        #define SORT_KEY_DRAW_0_PROGRAM_MASK   ( (uint64_t(BGFX_CONFIG_MAX_PROGRAMS-1) )<<SORT_KEY_DRAW_0_PROGRAM_SHIFT)

        #define SORT_KEY_DRAW_0_DEPTH_SHIFT    (SORT_KEY_DRAW_0_PROGRAM_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)
        #define SORT_KEY_DRAW_0_DEPTH_MASK     ( ( (UINT64_C(1)<<BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)-1)<<SORT_KEY_DRAW_0_DEPTH_SHIFT)

        //
        #define SORT_KEY_DRAW_1_DEPTH_SHIFT    (SORT_KEY_DRAW_TYPE_BIT_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)
        #define SORT_KEY_DRAW_1_DEPTH_MASK     ( ( (UINT64_C(1)<<BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)-1)<<SORT_KEY_DRAW_1_DEPTH_SHIFT)

        #define SORT_KEY_DRAW_1_TRANS_SHIFT    (SORT_KEY_DRAW_1_DEPTH_SHIFT - SORT_KEY_NUM_BITS_TRANS)
        #define SORT_KEY_DRAW_1_TRANS_MASK     (UINT64_C(0x3)<<SORT_KEY_DRAW_1_TRANS_SHIFT)

        #define SORT_KEY_DRAW_1_PROGRAM_SHIFT  (SORT_KEY_DRAW_1_TRANS_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM)
        #define SORT_KEY_DRAW_1_PROGRAM_MASK   ( (uint64_t(BGFX_CONFIG_MAX_PROGRAMS-1) )<<SORT_KEY_DRAW_1_PROGRAM_SHIFT)

        //
        #define SORT_KEY_DRAW_2_SEQ_SHIFT      (SORT_KEY_DRAW_TYPE_BIT_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_SEQ)
        #define SORT_KEY_DRAW_2_SEQ_MASK       ( ( (UINT64_C(1)<<BGFX_CONFIG_SORT_KEY_NUM_BITS_SEQ)-1)<<SORT_KEY_DRAW_2_SEQ_SHIFT)

        #define SORT_KEY_DRAW_2_TRANS_SHIFT    (SORT_KEY_DRAW_2_SEQ_SHIFT - SORT_KEY_NUM_BITS_TRANS)
        #define SORT_KEY_DRAW_2_TRANS_MASK     (UINT64_C(0x3)<<SORT_KEY_DRAW_2_TRANS_SHIFT)

        #define SORT_KEY_DRAW_2_PROGRAM_SHIFT  (SORT_KEY_DRAW_2_TRANS_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM)
        #define SORT_KEY_DRAW_2_PROGRAM_MASK   ( (uint64_t(BGFX_CONFIG_MAX_PROGRAMS-1) )<<SORT_KEY_DRAW_2_PROGRAM_SHIFT)


首先是

        SORT_KEY_NUM_BITS_TRANS                 2

它表示TRANS所占的位数。

接着

    SORT_KEY_DRAW_0_TRANS_SHIFT         (SORT_KEY_DRAW_TYPE_BIT_SHIFT - SORT_KEY_NUM_BITS_TRANS)

它计算出了TRANS位的偏移，也就是绘制类型偏移TRANS所占的位数。

然后

    SORT_KEY_DRAW_0_TRANS_MASK          (UINT64_C(0x3)<<SORT_KEY_DRAW_0_TRANS_SHIFT)

很明显，这是TRANS位的掩码，(UINT64_C(0x3))的二进制为**11**。

接着

    SORT_KEY_DRAW_0_PROGRAM_SHIFT       (SORT_KEY_DRAW_0_TRANS_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM)

这里使用到了**BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM**，它在BGFX中被设置为**9**。

DRAW_0_PROGRAM的偏移由TRANS的偏移-PROGRAM的位数得到。

接着

    SORT_KEY_DRAW_0_PROGRAM_MASK        ( (uint64_t(BGFX_CONFIG_MAX_PROGRAMS-1) )<<SORT_KEY_DRAW_0_PROGRAM_SHIFT)

这是**DRAW_0_PROGRAM**的掩码，没什么好说的。

下来

    SORT_KEY_DRAW_0_DEPTH_SHIFT     (SORT_KEY_DRAW_0_PROGRAM_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)
    SORT_KEY_DRAW_0_DEPTH_MASK      ( ( (UINT64_C(1)<<BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)-1)<<SORT_KEY_DRAW_0_DEPTH_SHIFT)

分别是DRAW_0_DETPH的偏移和掩码，**BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH**在BGFX中被设置为32。

接着

    SORT_KEY_DRAW_1_DEPTH_SHIFT     (SORT_KEY_DRAW_TYPE_BIT_SHIFT - BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)
    SORT_KEY_DRAW_1_DEPTH_MASK      ( ( (UINT64_C(1)<<BGFX_CONFIG_SORT_KEY_NUM_BITS_DEPTH)-1)<<SORT_KEY_DRAW_1_DEPTH_SHIFT)

分别是DRAW_1_DEPTH的偏移和掩码。

接着

    SORT_KEY_DRAW_1_TRANS_SHIFT     (SORT_KEY_DRAW_1_DEPTH_SHIFT - SORT_KEY_NUM_BITS_TRANS)
    SORT_KEY_DRAW_1_TRANS_MASK      (UINT64_C(0x3)<<SORT_KEY_DRAW_1_TRANS_SHIFT)

分别是DRAW_1_TRANS的偏移和掩码。

下面的一些类似就不再一一说明。


下面这些部分用于在编译期验证这些常量设置是否有冲突。

	BX_STATIC_ASSERT(BGFX_CONFIG_MAX_VIEWS <= (1<<SORK_KEY_NUM_BITS_VIEW) );
	BX_STATIC_ASSERT( (BGFX_CONFIG_MAX_PROGRAMS & (BGFX_CONFIG_MAX_PROGRAMS-1) ) == 0); // Must be power of 2.
	BX_STATIC_ASSERT( (0 // Render key mask shouldn't overlap.
		| SORT_KEY_VIEW_MASK
		| SORT_KEY_DRAW_BIT
		| SORT_KEY_DRAW_TYPE_MASK
		| SORT_KEY_DRAW_0_TRANS_MASK
		| SORT_KEY_DRAW_0_PROGRAM_MASK
		| SORT_KEY_DRAW_0_DEPTH_MASK
		) == (0
		^ SORT_KEY_VIEW_MASK
		^ SORT_KEY_DRAW_BIT
		^ SORT_KEY_DRAW_TYPE_MASK
		^ SORT_KEY_DRAW_0_TRANS_MASK
		^ SORT_KEY_DRAW_0_PROGRAM_MASK
		^ SORT_KEY_DRAW_0_DEPTH_MASK
		) );
	BX_STATIC_ASSERT( (0 // Render key mask shouldn't overlap.
		| SORT_KEY_VIEW_MASK
		| SORT_KEY_DRAW_BIT
		| SORT_KEY_DRAW_TYPE_MASK
		| SORT_KEY_DRAW_1_DEPTH_MASK
		| SORT_KEY_DRAW_1_TRANS_MASK
		| SORT_KEY_DRAW_1_PROGRAM_MASK
		) == (0
		^ SORT_KEY_VIEW_MASK
		^ SORT_KEY_DRAW_BIT
		^ SORT_KEY_DRAW_TYPE_MASK
		^ SORT_KEY_DRAW_1_DEPTH_MASK
		^ SORT_KEY_DRAW_1_TRANS_MASK
		^ SORT_KEY_DRAW_1_PROGRAM_MASK
		) );
	BX_STATIC_ASSERT( (0 // Render key mask shouldn't overlap.
		| SORT_KEY_VIEW_MASK
		| SORT_KEY_DRAW_BIT
		| SORT_KEY_DRAW_TYPE_MASK
		| SORT_KEY_DRAW_2_SEQ_MASK
		| SORT_KEY_DRAW_2_TRANS_MASK
		| SORT_KEY_DRAW_2_PROGRAM_MASK
		) == (0
		^ SORT_KEY_VIEW_MASK
		^ SORT_KEY_DRAW_BIT
		^ SORT_KEY_DRAW_TYPE_MASK
		^ SORT_KEY_DRAW_2_SEQ_MASK
		^ SORT_KEY_DRAW_2_TRANS_MASK
		^ SORT_KEY_DRAW_2_PROGRAM_MASK
		) );
	BX_STATIC_ASSERT( (0 // Compute key mask shouldn't overlap.
		| SORT_KEY_VIEW_MASK
		| SORT_KEY_DRAW_BIT
		| SORT_KEY_COMPUTE_SEQ_SHIFT
		| SORT_KEY_COMPUTE_PROGRAM_MASK
		) == (0
		^ SORT_KEY_VIEW_MASK
		^ SORT_KEY_DRAW_BIT
		^ SORT_KEY_COMPUTE_SEQ_SHIFT
		^ SORT_KEY_COMPUTE_PROGRAM_MASK
		) );

我们下说明一下下面这个图

	// |               3               2               1               0|
	// |fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210| Common
	// |vvvvvvvvd                                                       |
	// |       ^^                                                       |
	// |       ||                                                       |
	// |  view-+|                                                       |
	// |        +-draw                                                  |
	// |----------------------------------------------------------------| Draw Key 0 - Sort by program
	// |        |kkttpppppppppdddddddddddddddddddddddddddddddd          |
	// |        |   ^        ^                               ^          |
	// |        |   |        |                               |          |
	// |        |   +-trans  +-program                 depth-+          |
	// |        |                                                       |
	// |----------------------------------------------------------------| Draw Key 1 - Sort by depth
	// |        |kkddddddddddddddddddddddddddddddddttppppppppp          |
	// |        |                                ^^ ^        ^          |
	// |        |                                || +-trans  |          |
	// |        |                          depth-+   program-+          |
	// |        |                                                       |
	// |----------------------------------------------------------------| Draw Key 2 - Sequential
	// |        |kkssssssssssssssssssssttppppppppp                      |
	// |        |                     ^ ^        ^                      |
	// |        |                     | |        |                      |
	// |        |                 seq-+ +-trans  +-program              |
	// |        |                                                       |
	// |----------------------------------------------------------------| Compute Key
	// |        |ssssssssssssssssssssppppppppp                          |
	// |        |                   ^        ^                          |
	// |        |                   |        |                          |
	// |        |               seq-+        +-program                  |
	// |        |                                                       |
	// |--------+-------------------------------------------------------|
	//

最上面的0,1,2,3表示字。
0~f表示16进制，v表示视图占的位。

k表示DRAW类型。
t表示TRANS。

需要注意图和实际的设置并不完全对应，可能是作者忘记更新示图:)。

        enum Enum
		{
			SortProgram,
			SortDepth,
			SortSequence,
		};

SortKey的**encodeDraw(Enum _type)**
根据_type来生成一个key。

    if (SortDepth == _type)
	{
		const uint64_t depth   = (uint64_t(m_depth  ) << SORT_KEY_DRAW_1_DEPTH_SHIFT  ) & SORT_KEY_DRAW_1_DEPTH_MASK;
		const uint64_t program = (uint64_t(m_program) << SORT_KEY_DRAW_1_PROGRAM_SHIFT) & SORT_KEY_DRAW_1_PROGRAM_MASK;
		const uint64_t trans   = (uint64_t(m_trans  ) << SORT_KEY_DRAW_1_TRANS_SHIFT  ) & SORT_KEY_DRAW_1_TRANS_MASK;
		const uint64_t view    = (uint64_t(m_view   ) << SORT_KEY_VIEW_SHIFT          ) & SORT_KEY_VIEW_MASK;
		const uint64_t key     = view|SORT_KEY_DRAW_BIT|SORT_KEY_DRAW_TYPE_DEPTH|depth|trans|program;

		return key;
	}

其它比如SortProgram,SortDepth和SortSequence与之类似。

SortKey的**decode**与之相反，把key的中信息设置到SortKey的相应成员变量中。

