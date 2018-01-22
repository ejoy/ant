	.file	"lvm.c"
	.section	.text.unlikely,"x"
.LCOLDB0:
	.text
.LHOTB0:
	.p2align 4,,15
	.def	l_strcmp;	.scl	3;	.type	32;	.endef
	.seh_proc	l_strcmp
l_strcmp:
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$40, %rsp
	.seh_stackalloc	40
	.seh_endprologue
	cmpb	$4, 8(%rcx)
	leaq	24(%rcx), %rbx
	je	.L12
	movq	16(%rcx), %rbp
.L3:
	cmpb	$4, 8(%rdx)
	leaq	24(%rdx), %rsi
	je	.L13
	movq	16(%rdx), %rdi
	jmp	.L5
	.p2align 4,,10
.L15:
	movq	%rbx, %rcx
	call	strlen
	cmpq	%rdi, %rax
	je	.L14
	cmpq	%rbp, %rax
	je	.L10
	addq	$1, %rax
	addq	%rax, %rbx
	subq	%rax, %rbp
	addq	%rax, %rsi
	subq	%rax, %rdi
.L5:
	movq	%rsi, %rdx
	movq	%rbx, %rcx
	call	strcoll
	testl	%eax, %eax
	je	.L15
	addq	$40, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L14:
	xorl	%eax, %eax
	cmpq	%rdi, %rbp
	setne	%al
	addq	$40, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L10:
	movl	$-1, %eax
	addq	$40, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L13:
	movzbl	11(%rdx), %edi
	jmp	.L5
	.p2align 4,,10
.L12:
	movzbl	11(%rcx), %ebp
	jmp	.L3
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE0:
	.text
.LHOTE0:
	.section	.text.unlikely,"x"
.LCOLDB1:
	.text
.LHOTB1:
	.p2align 4,,15
	.def	copy2buff;	.scl	3;	.type	32;	.endef
	.seh_proc	copy2buff
copy2buff:
	pushq	%r12
	.seh_pushreg	%r12
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$32, %rsp
	.seh_stackalloc	32
	.seh_endprologue
	xorl	%edi, %edi
	movslq	%edx, %rax
	movq	%rcx, %rbx
	movq	%r8, %r12
	movq	%rax, %rsi
	salq	$4, %rax
	subq	%rax, %rbx
	jmp	.L19
	.p2align 4,,10
.L17:
	movq	16(%rax), %rbp
.L18:
	leaq	(%r12,%rdi), %rcx
	movq	%rbp, %r8
	subl	$1, %esi
	leaq	24(%rax), %rdx
	addq	%rbp, %rdi
	addq	$16, %rbx
	call	memcpy
	testl	%esi, %esi
	jle	.L21
.L19:
	movq	(%rbx), %rax
	cmpb	$4, 8(%rax)
	jne	.L17
	movzbl	11(%rax), %ebp
	jmp	.L18
	.p2align 4,,10
.L21:
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	ret
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE1:
	.text
.LHOTE1:
	.section	.text.unlikely,"x"
.LCOLDB2:
	.text
.LHOTB2:
	.p2align 4,,15
	.def	lua_checksig_.part.3;	.scl	3;	.type	32;	.endef
	.seh_proc	lua_checksig_.part.3
lua_checksig_.part.3:
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$32, %rsp
	.seh_stackalloc	32
	.seh_endprologue
	movq	$0, skynet_sig_L(%rip)
	movq	%rcx, %rbx
	call	lua_pushnil
	movq	%rbx, %rcx
	addq	$32, %rsp
	popq	%rbx
	jmp	lua_error
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE2:
	.text
.LHOTE2:
	.section	.text.unlikely,"x"
.LCOLDB3:
	.text
.LHOTB3:
	.p2align 4,,15
	.globl	lua_checksig_
	.def	lua_checksig_;	.scl	2;	.type	32;	.endef
	.seh_proc	lua_checksig_
lua_checksig_:
	.seh_endprologue
	movq	skynet_sig_L(%rip), %rdx
	movq	24(%rcx), %rax
	cmpq	%rdx, 200(%rax)
	je	.L25
	ret
	.p2align 4,,10
.L25:
	jmp	lua_checksig_.part.3
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE3:
	.text
.LHOTE3:
	.section	.text.unlikely,"x"
.LCOLDB4:
	.text
.LHOTB4:
	.p2align 4,,15
	.globl	luaV_tonumber_
	.def	luaV_tonumber_;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_tonumber_
luaV_tonumber_:
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$56, %rsp
	.seh_stackalloc	56
	.seh_endprologue
	movl	8(%rcx), %eax
	cmpl	$19, %eax
	je	.L36
	andl	$15, %eax
	movl	%eax, %r8d
	xorl	%eax, %eax
	cmpl	$4, %r8d
	je	.L37
.L28:
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	ret
	.p2align 4,,10
.L36:
	pxor	%xmm0, %xmm0
	cvtsi2sdq	(%rcx), %xmm0
	movb	$1, %al
	movsd	%xmm0, (%rdx)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	ret
	.p2align 4,,10
.L37:
	movq	(%rcx), %rax
	movq	%rcx, %rbx
	movq	%rdx, %rsi
	leaq	32(%rsp), %rdx
	leaq	24(%rax), %rcx
	call	luaO_str2num
	movq	(%rbx), %rdx
	movq	%rax, %rcx
	cmpb	$4, 8(%rdx)
	je	.L38
	movq	16(%rdx), %rdx
	addq	$1, %rdx
.L30:
	xorl	%eax, %eax
	cmpq	%rdx, %rcx
	jne	.L28
	cmpl	$19, 40(%rsp)
	movsd	32(%rsp), %xmm0
	je	.L39
.L33:
	movsd	%xmm0, (%rsi)
	movl	$1, %eax
	jmp	.L28
	.p2align 4,,10
.L39:
	pxor	%xmm0, %xmm0
	cvtsi2sdq	32(%rsp), %xmm0
	jmp	.L33
	.p2align 4,,10
.L38:
	movzbl	11(%rdx), %edx
	addq	$1, %rdx
	jmp	.L30
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE4:
	.text
.LHOTE4:
	.section	.text.unlikely,"x"
.LCOLDB8:
	.text
.LHOTB8:
	.p2align 4,,15
	.globl	luaV_tointeger
	.def	luaV_tointeger;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_tointeger
luaV_tointeger:
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$72, %rsp
	.seh_stackalloc	72
	movaps	%xmm6, 48(%rsp)
	.seh_savexmm	%xmm6, 48
	.seh_endprologue
	movq	%rcx, %rbx
	movq	%rdx, %rdi
	movl	%r8d, %ebp
	leaq	32(%rsp), %rsi
	jmp	.L51
	.p2align 4,,10
.L49:
	movq	16(%rdx), %rcx
	movq	%rsi, %rbx
	addq	$1, %rcx
	cmpq	%rcx, %rax
	jne	.L47
.L41:
.L51:
	movl	8(%rbx), %eax
	cmpl	$3, %eax
	je	.L60
	cmpl	$19, %eax
	je	.L61
	andl	$15, %eax
	cmpl	$4, %eax
	jne	.L47
	movq	(%rbx), %rax
	movq	%rsi, %rdx
	leaq	24(%rax), %rcx
	call	luaO_str2num
	movq	(%rbx), %rdx
	cmpb	$4, 8(%rdx)
	jne	.L49
	movzbl	11(%rdx), %ecx
	movq	%rsi, %rbx
	addq	$1, %rcx
	cmpq	%rcx, %rax
	je	.L51
	.p2align 4,,10
.L47:
	xorl	%eax, %eax
.L46:
	movaps	48(%rsp), %xmm6
	addq	$72, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L60:
	movsd	(%rbx), %xmm6
	movapd	%xmm6, %xmm0
	call	floor
	ucomisd	%xmm0, %xmm6
	jp	.L52
	je	.L43
.L52:
	testl	%ebp, %ebp
	je	.L47
	cmpl	$1, %ebp
	jle	.L43
	addsd	.LC5(%rip), %xmm0
.L43:
	ucomisd	.LC6(%rip), %xmm0
	jb	.L47
	movsd	.LC7(%rip), %xmm1
	ucomisd	%xmm0, %xmm1
	jbe	.L47
	cvttsd2siq	%xmm0, %rax
	movq	%rax, (%rdi)
	movl	$1, %eax
	jmp	.L46
	.p2align 4,,10
.L61:
	movq	(%rbx), %rax
	movaps	48(%rsp), %xmm6
	movq	%rax, (%rdi)
	movl	$1, %eax
	addq	$72, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE8:
	.text
.LHOTE8:
	.section .rdata,"dr"
.LC9:
	.ascii "index\0"
	.align 8
.LC10:
	.ascii "'__index' chain too long; possible loop\0"
	.section	.text.unlikely,"x"
.LCOLDB11:
	.text
.LHOTB11:
	.p2align 4,,15
	.globl	luaV_finishget
	.def	luaV_finishget;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_finishget
luaV_finishget:
	pushq	%r13
	.seh_pushreg	%r13
	pushq	%r12
	.seh_pushreg	%r12
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$56, %rsp
	.seh_stackalloc	56
	.seh_endprologue
	movl	$2000, %ebx
	movq	144(%rsp), %rax
	testq	%rax, %rax
	movq	%rcx, %rdi
	movq	%rdx, %r12
	movq	%r8, %rbp
	movq	%r9, %rsi
	je	.L77
	.p2align 4,,10
.L63:
	movq	(%r12), %rax
	movq	40(%rax), %rcx
	testq	%rcx, %rcx
	je	.L67
	testb	$1, 10(%rcx)
	je	.L78
.L67:
	movl	$0, 8(%rsi)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	ret
	.p2align 4,,10
.L78:
	movq	24(%rdi), %rdx
	movq	224(%rdx), %r8
	xorl	%edx, %edx
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %r13
	je	.L67
	movl	8(%rax), %r10d
.L64:
	movl	%r10d, %ecx
	andl	$15, %ecx
	cmpl	$6, %ecx
	je	.L79
	xorl	%eax, %eax
	cmpl	$69, %r10d
	je	.L80
.L69:
	subl	$1, %ebx
	je	.L81
	testq	%rax, %rax
	movq	%r13, %r12
	jne	.L63
.L77:
	xorl	%r8d, %r8d
	movq	%r12, %rdx
	movq	%rdi, %rcx
	call	luaT_gettmbyobj
	movl	8(%rax), %r10d
	movq	%rax, %r13
	testl	%r10d, %r10d
	jne	.L64
	leaq	.LC9(%rip), %r8
	movq	%r12, %rdx
	movq	%rdi, %rcx
	call	luaG_typeerror
	.p2align 4,,10
.L80:
	movq	0(%r13), %rcx
	movq	%rbp, %rdx
	call	luaH_get
	movl	8(%rax), %edx
	testl	%edx, %edx
	je	.L69
	movq	8(%rax), %rdx
	movq	(%rax), %rax
	movq	%rdx, 8(%rsi)
	movq	%rax, (%rsi)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	ret
	.p2align 4,,10
.L79:
	movq	%rsi, 32(%rsp)
	movq	%rbp, %r9
	movq	%r12, %r8
	movq	%r13, %rdx
	movl	$1, 40(%rsp)
	movq	%rdi, %rcx
	call	luaT_callTM
	nop
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	ret
	.p2align 4,,10
.L81:
	leaq	.LC10(%rip), %rdx
	movq	%rdi, %rcx
	call	luaG_runerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE11:
	.text
.LHOTE11:
	.section .rdata,"dr"
	.align 8
.LC12:
	.ascii "'__newindex' chain too long; possible loop\0"
	.section	.text.unlikely,"x"
.LCOLDB13:
	.text
.LHOTB13:
	.p2align 4,,15
	.globl	luaV_finishset
	.def	luaV_finishset;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_finishset
luaV_finishset:
	pushq	%r15
	.seh_pushreg	%r15
	pushq	%r14
	.seh_pushreg	%r14
	pushq	%r13
	.seh_pushreg	%r13
	pushq	%r12
	.seh_pushreg	%r12
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$56, %rsp
	.seh_stackalloc	56
	.seh_endprologue
	movl	$2000, %esi
	movq	160(%rsp), %rbx
	testq	%rbx, %rbx
	movq	%rcx, %rdi
	movq	%rdx, %r13
	movq	%r8, %r12
	movq	%r9, %rbp
	je	.L83
	.p2align 4,,10
.L129:
	movq	0(%r13), %r15
	movq	40(%r15), %rcx
	testq	%rcx, %rcx
	je	.L97
	testb	$2, 10(%rcx)
	je	.L123
.L97:
	cmpq	.refptr.luaO_nilobject_(%rip), %rbx
	movq	%rbx, %rax
	je	.L124
.L86:
	movq	0(%rbp), %rcx
	movq	8(%rbp), %rbx
	movq	%rcx, (%rax)
	movq	%rbx, 8(%rax)
	movb	$0, 10(%r15)
	testb	$64, 8(%rbp)
	je	.L82
	testb	$4, 9(%r15)
	je	.L82
	movq	0(%rbp), %rax
	testb	$3, 9(%rax)
	jne	.L125
	.p2align 4,,10
.L82:
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	ret
	.p2align 4,,10
.L123:
	movq	24(%rdi), %rdx
	movq	232(%rdx), %r8
	movl	$1, %edx
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %r14
	je	.L97
	movl	8(%rax), %r10d
.L90:
	movl	%r10d, %ecx
	andl	$15, %ecx
	cmpl	$6, %ecx
	je	.L126
	xorl	%ebx, %ebx
	cmpl	$69, %r10d
	je	.L127
.L92:
	subl	$1, %esi
	je	.L128
	testq	%rbx, %rbx
	movq	%r14, %r13
	jne	.L129
.L83:
	movl	$1, %r8d
	movq	%r13, %rdx
	movq	%rdi, %rcx
	call	luaT_gettmbyobj
	movl	8(%rax), %r10d
	movq	%rax, %r14
	testl	%r10d, %r10d
	jne	.L90
	leaq	.LC9(%rip), %r8
	movq	%r13, %rdx
	movq	%rdi, %rcx
	call	luaG_typeerror
	.p2align 4,,10
.L127:
	movq	(%r14), %rcx
	movq	%r12, %rdx
	call	luaH_get
	movq	%rax, %rbx
	movl	8(%rax), %eax
	testl	%eax, %eax
	je	.L92
	testb	$64, 8(%rbp)
	je	.L93
	movq	(%r14), %rdx
	testb	$4, 9(%rdx)
	je	.L93
	movq	0(%rbp), %rax
	testb	$3, 9(%rax)
	jne	.L130
	.p2align 4,,10
.L93:
	movq	0(%rbp), %rax
	movq	8(%rbp), %rdx
	movq	%rax, (%rbx)
	movq	%rdx, 8(%rbx)
	jmp	.L82
	.p2align 4,,10
.L126:
	movq	%rbp, 32(%rsp)
	movq	%r12, %r9
	movq	%r13, %r8
	movq	%r14, %rdx
	movl	$0, 40(%rsp)
	movq	%rdi, %rcx
	call	luaT_callTM
	jmp	.L82
.L130:
	movq	%rdi, %rcx
	call	luaC_barrierback_
	jmp	.L93
.L128:
	leaq	.LC12(%rip), %rdx
	movq	%rdi, %rcx
	call	luaG_runerror
.L125:
	movq	%r15, %rdx
	movq	%rdi, %rcx
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	jmp	luaC_barrierback_
	.p2align 4,,10
.L124:
	movq	%r12, %r8
	movq	%r15, %rdx
	movq	%rdi, %rcx
	call	luaH_newkey
	jmp	.L86
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE13:
	.text
.LHOTE13:
	.section	.text.unlikely,"x"
.LCOLDB14:
	.text
.LHOTB14:
	.p2align 4,,15
	.globl	luaV_lessthan
	.def	luaV_lessthan;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_lessthan
luaV_lessthan:
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$32, %rsp
	.seh_stackalloc	32
	.seh_endprologue
	movq	%rdx, %rbx
	movl	8(%rdx), %edx
	movq	%rcx, %rdi
	movq	%r8, %rsi
	movl	%edx, %eax
	andl	$15, %eax
	cmpl	$3, %eax
	je	.L153
	cmpl	$4, %eax
	jne	.L133
	movl	8(%r8), %eax
	andl	$15, %eax
	cmpl	$4, %eax
	je	.L154
.L133:
	movl	$20, %r9d
	movq	%rsi, %r8
	movq	%rbx, %rdx
	movq	%rdi, %rcx
	call	luaT_callorderTM
	testl	%eax, %eax
	js	.L155
.L136:
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L153:
	movl	8(%r8), %eax
	movl	%eax, %ecx
	andl	$15, %ecx
	cmpl	$3, %ecx
	jne	.L133
	cmpl	$19, %edx
	je	.L156
	cmpl	$3, %eax
	movsd	(%rbx), %xmm0
	je	.L157
	ucomisd	%xmm0, %xmm0
	jp	.L145
	movabsq	$9007199254740992, %rax
	movq	(%r8), %rdx
	movabsq	$18014398509481984, %rcx
	addq	%rdx, %rax
	cmpq	%rcx, %rax
	jbe	.L140
	xorl	%eax, %eax
	ucomisd	.LC7(%rip), %xmm0
	jae	.L136
	ucomisd	.LC6(%rip), %xmm0
	movl	$1, %eax
	jb	.L136
	cvttsd2siq	%xmm0, %rax
	cmpq	%rax, %rdx
	setg	%al
	movzbl	%al, %eax
	jmp	.L136
	.p2align 4,,10
.L154:
	movq	(%r8), %rdx
	movq	(%rbx), %rcx
	call	l_strcmp
	shrl	$31, %eax
	jmp	.L136
	.p2align 4,,10
.L156:
	cmpl	$19, %eax
	movq	(%rbx), %rdx
	je	.L158
	movabsq	$9007199254740992, %rax
	movsd	(%r8), %xmm1
	movabsq	$18014398509481984, %rcx
	addq	%rdx, %rax
	cmpq	%rcx, %rax
	jbe	.L137
	ucomisd	.LC7(%rip), %xmm1
	movl	$1, %eax
	jae	.L136
	ucomisd	.LC6(%rip), %xmm1
	jbe	.L145
	cvttsd2siq	%xmm1, %rax
	cmpq	%rax, %rdx
	setl	%al
	movzbl	%al, %eax
	jmp	.L136
.L145:
	xorl	%eax, %eax
	jmp	.L136
	.p2align 4,,10
.L140:
	pxor	%xmm1, %xmm1
	cvtsi2sdq	%rdx, %xmm1
	xorl	%eax, %eax
	ucomisd	%xmm1, %xmm0
	setb	%al
	jmp	.L136
.L157:
	movsd	(%r8), %xmm1
	xorl	%eax, %eax
	ucomisd	%xmm0, %xmm1
	seta	%al
	jmp	.L136
.L137:
	pxor	%xmm0, %xmm0
	cvtsi2sdq	%rdx, %xmm0
	xorl	%eax, %eax
	ucomisd	%xmm0, %xmm1
	seta	%al
	jmp	.L136
.L158:
	xorl	%eax, %eax
	cmpq	(%r8), %rdx
	setl	%al
	jmp	.L136
.L155:
	movq	%rsi, %r8
	movq	%rbx, %rdx
	movq	%rdi, %rcx
	call	luaG_ordererror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE14:
	.text
.LHOTE14:
	.section	.text.unlikely,"x"
.LCOLDB15:
	.text
.LHOTB15:
	.p2align 4,,15
	.globl	luaV_lessequal
	.def	luaV_lessequal;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_lessequal
luaV_lessequal:
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$32, %rsp
	.seh_stackalloc	32
	.seh_endprologue
	movq	%rdx, %rbx
	movl	8(%rdx), %edx
	movq	%rcx, %rdi
	movq	%r8, %rsi
	movl	%edx, %eax
	andl	$15, %eax
	cmpl	$3, %eax
	je	.L182
	cmpl	$4, %eax
	jne	.L161
	movl	8(%r8), %eax
	andl	$15, %eax
	cmpl	$4, %eax
	je	.L183
.L161:
	movl	$21, %r9d
	movq	%rsi, %r8
	movq	%rbx, %rdx
	movq	%rdi, %rcx
	call	luaT_callorderTM
	testl	%eax, %eax
	js	.L184
.L164:
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L182:
	movl	8(%r8), %eax
	movl	%eax, %ecx
	andl	$15, %ecx
	cmpl	$3, %ecx
	jne	.L161
	cmpl	$19, %edx
	je	.L185
	cmpl	$3, %eax
	movsd	(%rbx), %xmm0
	je	.L186
	ucomisd	%xmm0, %xmm0
	jp	.L174
	movabsq	$9007199254740992, %rax
	movq	(%r8), %rdx
	movabsq	$18014398509481984, %rcx
	addq	%rdx, %rax
	cmpq	%rcx, %rax
	jbe	.L168
	xorl	%eax, %eax
	ucomisd	.LC7(%rip), %xmm0
	jae	.L164
	ucomisd	.LC6(%rip), %xmm0
	movl	$1, %eax
	jbe	.L164
	cvttsd2siq	%xmm0, %rax
	cmpq	%rax, %rdx
	setge	%al
	movzbl	%al, %eax
	jmp	.L164
	.p2align 4,,10
.L184:
	movq	32(%rdi), %rax
	movq	%rsi, %rdx
	movl	$20, %r9d
	movq	%rbx, %r8
	movq	%rdi, %rcx
	orw	$128, 66(%rax)
	call	luaT_callorderTM
	movq	32(%rdi), %rdx
	xorw	$128, 66(%rdx)
	testl	%eax, %eax
	js	.L187
	sete	%al
	movzbl	%al, %eax
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L183:
	movq	(%r8), %rdx
	movq	(%rbx), %rcx
	call	l_strcmp
	testl	%eax, %eax
	setle	%al
	movzbl	%al, %eax
	jmp	.L164
	.p2align 4,,10
.L185:
	cmpl	$19, %eax
	movq	(%rbx), %rdx
	je	.L188
	movabsq	$9007199254740992, %rax
	movsd	(%r8), %xmm1
	movabsq	$18014398509481984, %rcx
	addq	%rdx, %rax
	cmpq	%rcx, %rax
	jbe	.L165
	ucomisd	.LC7(%rip), %xmm1
	movl	$1, %eax
	jae	.L164
	ucomisd	.LC6(%rip), %xmm1
	jb	.L174
	cvttsd2siq	%xmm1, %rax
	cmpq	%rax, %rdx
	setle	%al
	movzbl	%al, %eax
	jmp	.L164
.L174:
	xorl	%eax, %eax
	jmp	.L164
	.p2align 4,,10
.L168:
	pxor	%xmm1, %xmm1
	cvtsi2sdq	%rdx, %xmm1
	xorl	%eax, %eax
	ucomisd	%xmm1, %xmm0
	setbe	%al
	jmp	.L164
.L186:
	movsd	(%r8), %xmm1
	xorl	%eax, %eax
	ucomisd	%xmm0, %xmm1
	setae	%al
	jmp	.L164
.L165:
	pxor	%xmm0, %xmm0
	cvtsi2sdq	%rdx, %xmm0
	xorl	%eax, %eax
	ucomisd	%xmm0, %xmm1
	setae	%al
	jmp	.L164
.L188:
	xorl	%eax, %eax
	cmpq	(%r8), %rdx
	setle	%al
	jmp	.L164
.L187:
	movq	%rsi, %r8
	movq	%rbx, %rdx
	movq	%rdi, %rcx
	call	luaG_ordererror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE15:
	.text
.LHOTE15:
	.section	.text.unlikely,"x"
.LCOLDB16:
	.text
.LHOTB16:
	.p2align 4,,15
	.globl	luaV_equalobj
	.def	luaV_equalobj;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_equalobj
luaV_equalobj:
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$72, %rsp
	.seh_stackalloc	72
	.seh_endprologue
	movl	8(%r8), %eax
	movl	8(%rdx), %r10d
	movl	%eax, %r11d
	movq	%rcx, %rbp
	movq	%rdx, %rdi
	xorl	%r10d, %r11d
	movq	%r8, %rsi
	movl	%r11d, %ebx
	andl	$63, %ebx
	je	.L190
	movl	%r11d, %ebx
	andl	$15, %ebx
	jne	.L193
	movl	%r10d, %edx
	andl	$15, %edx
	cmpl	$3, %edx
	je	.L248
.L193:
	xorl	%ebx, %ebx
	movl	%ebx, %eax
	addq	$72, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L190:
	andl	$63, %r10d
	cmpl	$22, %r10d
	ja	.L201
	leaq	.L202(%rip), %rax
	movslq	(%rax,%r10,4), %rdx
	addq	%rdx, %rax
	jmp	*%rax
	.section .rdata,"dr"
	.align 4
.L202:
	.long	.L224-.L202
	.long	.L203-.L202
	.long	.L201-.L202
	.long	.L205-.L202
	.long	.L201-.L202
	.long	.L207-.L202
	.long	.L201-.L202
	.long	.L208-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.long	.L210-.L202
	.long	.L201-.L202
	.long	.L201-.L202
	.text
	.p2align 4,,10
.L201:
	xorl	%ebx, %ebx
	movq	(%rsi), %rax
	cmpq	%rax, (%rdi)
	sete	%bl
.L192:
	movl	%ebx, %eax
	addq	$72, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L248:
	cmpl	$19, %r10d
	jne	.L194
	movq	(%rdi), %rdx
	movq	%rdx, 48(%rsp)
.L195:
	cmpl	$19, %eax
	je	.L249
	leaq	56(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rsi, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L192
	movq	56(%rsp), %rax
.L199:
	xorl	%ebx, %ebx
	cmpq	48(%rsp), %rax
	sete	%bl
	jmp	.L192
	.p2align 4,,10
.L208:
	movq	(%rdi), %rax
	cmpq	(%r8), %rax
	je	.L224
	testq	%rcx, %rcx
	je	.L193
	movq	16(%rax), %rcx
	testq	%rcx, %rcx
	je	.L216
	testb	$32, 10(%rcx)
	je	.L250
.L216:
	movq	(%rsi), %rax
	movq	16(%rax), %rcx
	testq	%rcx, %rcx
	je	.L192
.L221:
	testb	$32, 10(%rcx)
	jne	.L192
	movq	24(%rbp), %rax
	movl	$5, %edx
	movq	264(%rax), %r8
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %rdx
	je	.L193
	.p2align 4,,10
.L223:
	movl	$1, 40(%rsp)
	movq	16(%rbp), %rcx
	movq	%rsi, %r9
	movq	%rdi, %r8
	movq	%rcx, 32(%rsp)
	movq	%rbp, %rcx
	call	luaT_callTM
	movq	16(%rbp), %rdx
	movl	8(%rdx), %eax
	testl	%eax, %eax
	je	.L192
	cmpl	$1, %eax
	jne	.L224
	movl	(%rdx), %eax
	testl	%eax, %eax
	je	.L192
	.p2align 4,,10
.L224:
	movl	$1, %ebx
	jmp	.L192
	.p2align 4,,10
.L194:
	leaq	48(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rdi, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L192
	movl	8(%rsi), %eax
	jmp	.L195
	.p2align 4,,10
.L203:
	xorl	%ebx, %ebx
	movl	(%r8), %eax
	cmpl	%eax, (%rdi)
	sete	%bl
	jmp	.L192
	.p2align 4,,10
.L210:
	movq	(%r8), %rdx
	movq	(%rdi), %rcx
	call	luaS_eqlngstr
	movl	%eax, %ebx
	jmp	.L192
	.p2align 4,,10
.L205:
	xorl	%ebx, %ebx
	movsd	(%rdi), %xmm0
	movl	$0, %eax
	ucomisd	(%r8), %xmm0
	setnp	%bl
	cmovne	%eax, %ebx
	jmp	.L192
	.p2align 4,,10
.L207:
	movq	(%rdi), %rax
	cmpq	(%r8), %rax
	je	.L224
	testq	%rcx, %rcx
	je	.L193
	movq	40(%rax), %rcx
	testq	%rcx, %rcx
	je	.L222
	testb	$32, 10(%rcx)
	je	.L251
.L222:
	movq	(%rsi), %rax
	movq	40(%rax), %rcx
	testq	%rcx, %rcx
	jne	.L221
	jmp	.L192
	.p2align 4,,10
.L249:
	movq	(%rsi), %rax
	jmp	.L199
.L250:
	movq	24(%rbp), %rax
	movl	$5, %edx
	movq	264(%rax), %r8
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %rdx
	jne	.L223
	jmp	.L216
	.p2align 4,,10
.L251:
	movq	24(%rbp), %rax
	movl	$5, %edx
	movq	264(%rax), %r8
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %rdx
	jne	.L223
	jmp	.L222
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE16:
	.text
.LHOTE16:
	.section .rdata,"dr"
.LC17:
	.ascii "string length overflow\0"
	.section	.text.unlikely,"x"
.LCOLDB18:
	.text
.LHOTB18:
	.p2align 4,,15
	.globl	luaV_concat
	.def	luaV_concat;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_concat
luaV_concat:
	pushq	%r15
	.seh_pushreg	%r15
	pushq	%r14
	.seh_pushreg	%r14
	pushq	%r13
	.seh_pushreg	%r13
	pushq	%r12
	.seh_pushreg	%r12
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$120, %rsp
	.seh_stackalloc	120
	.seh_endprologue
	movabsq	$9223372036854775807, %r12
	movq	16(%rcx), %r15
	leaq	64(%rsp), %rax
	movq	%rcx, %rbp
	movl	%edx, %edi
	movq	%rax, 48(%rsp)
	jmp	.L270
	.p2align 4,,10
.L282:
	cmpl	$3, %edx
	je	.L280
.L253:
	leaq	-32(%r15), %rdx
	movl	$22, 32(%rsp)
	movq	%rbp, %rcx
	movq	$-16, %rbx
	leaq	-16(%r15), %r8
	movq	%rdx, %r9
	movl	$-1, %r13d
	call	luaT_trybinTM
.L255:
	addq	16(%rbp), %rbx
	addl	%r13d, %edi
	cmpl	$1, %edi
	movq	%rbx, %r15
	movq	%rbx, 16(%rbp)
	jle	.L281
.L270:
	movl	-24(%r15), %eax
	movl	%eax, %edx
	andl	$15, %edx
	subl	$3, %edx
	cmpl	$1, %edx
	ja	.L253
	movl	-8(%r15), %ecx
	movl	%ecx, %edx
	andl	$15, %edx
	cmpl	$4, %edx
	jne	.L282
.L254:
	cmpl	$68, %ecx
	je	.L283
.L256:
	cmpl	$68, %eax
	je	.L284
.L257:
	movq	-16(%r15), %rdx
	cmpb	$4, 8(%rdx)
	je	.L285
	movq	16(%rdx), %rsi
.L261:
	cmpl	$1, %edi
	jle	.L272
	leaq	-32(%r15), %r14
	movl	$1, %ebx
	jmp	.L260
	.p2align 4,,10
.L262:
	movq	16(%rax), %rax
.L263:
	movq	%r12, %rdx
	subq	%rsi, %rdx
	cmpq	%rdx, %rax
	jae	.L286
	leal	1(%rbx), %r9d
	addq	$1, %rbx
	addq	%rax, %rsi
	subq	$16, %r14
	cmpl	%ebx, %edi
	jle	.L287
	movl	8(%r14), %eax
.L260:
	movq	%rbx, %rdx
	andl	$15, %eax
	salq	$4, %rdx
	cmpl	$4, %eax
	je	.L266
	cmpl	$3, %eax
	jne	.L288
	movq	%r14, %rdx
	movq	%rbp, %rcx
	call	luaO_tostring
.L266:
	movq	(%r14), %rax
	cmpb	$4, 8(%rax)
	jne	.L262
	movzbl	11(%rax), %eax
	jmp	.L263
	.p2align 4,,10
.L287:
	movslq	%r9d, %rbx
	movl	$1, %r10d
	movq	%rbx, %r14
	negq	%rbx
	subl	%r9d, %r10d
	salq	$4, %r14
	salq	$4, %rbx
	movl	%r10d, %r13d
	negq	%r14
	addq	$16, %rbx
.L259:
	cmpq	$40, %rsi
	ja	.L268
	movq	48(%rsp), %r8
	movl	%r9d, %edx
	movq	%r15, %rcx
	call	copy2buff
	movq	48(%rsp), %rdx
	movq	%rsi, %r8
	movq	%rbp, %rcx
	call	luaS_newlstr
	movq	%rax, %rsi
.L269:
	addq	%r15, %r14
	movq	%rsi, (%r14)
	movzbl	8(%rsi), %eax
	orl	$64, %eax
	movzbl	%al, %eax
	movl	%eax, 8(%r14)
	jmp	.L255
	.p2align 4,,10
.L268:
	movq	%rsi, %rdx
	movq	%rbp, %rcx
	movl	%r9d, 60(%rsp)
	call	luaS_createlngstrobj
	movl	60(%rsp), %r9d
	movq	%r15, %rcx
	leaq	24(%rax), %r8
	movq	%rax, %rsi
	movl	%r9d, %edx
	call	copy2buff
	jmp	.L269
	.p2align 4,,10
.L288:
	movl	$1, %r10d
	movl	%ebx, %r9d
	negq	%rdx
	subl	%ebx, %r10d
	negq	%rbx
	movq	%rdx, %r14
	salq	$4, %rbx
	movl	%r10d, %r13d
	addq	$16, %rbx
	jmp	.L259
	.p2align 4,,10
.L283:
	movq	-16(%r15), %rdx
	cmpb	$0, 11(%rdx)
	jne	.L256
	andl	$15, %eax
	movq	$-16, %rbx
	movl	$-1, %r13d
	cmpl	$3, %eax
	jne	.L255
	leaq	-32(%r15), %rdx
	movq	%rbp, %rcx
	call	luaO_tostring
	jmp	.L255
	.p2align 4,,10
.L280:
	leaq	-16(%r15), %rdx
	movq	%rbp, %rcx
	call	luaO_tostring
	movl	-8(%r15), %ecx
	movl	-24(%r15), %eax
	jmp	.L254
	.p2align 4,,10
.L281:
	addq	$120, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	ret
	.p2align 4,,10
.L284:
	movq	-32(%r15), %rdx
	cmpb	$0, 11(%rdx)
	jne	.L257
	movq	-16(%r15), %rax
	movq	$-16, %rbx
	movl	$-1, %r13d
	movq	-8(%r15), %rdx
	movq	%rax, -32(%r15)
	movq	%rdx, -24(%r15)
	jmp	.L255
	.p2align 4,,10
.L285:
	movzbl	11(%rdx), %esi
	jmp	.L261
.L272:
	xorl	%ebx, %ebx
	xorl	%r13d, %r13d
	movq	$-16, %r14
	movl	$1, %r9d
	jmp	.L259
.L286:
	leaq	.LC17(%rip), %rdx
	movq	%rbp, %rcx
	call	luaG_runerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE18:
	.text
.LHOTE18:
	.section .rdata,"dr"
.LC19:
	.ascii "get length of\0"
	.section	.text.unlikely,"x"
.LCOLDB20:
	.text
.LHOTB20:
	.p2align 4,,15
	.globl	luaV_objlen
	.def	luaV_objlen;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_objlen
luaV_objlen:
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$56, %rsp
	.seh_stackalloc	56
	.seh_endprologue
	movl	8(%r8), %eax
	andl	$63, %eax
	movq	%rcx, %rdi
	movq	%rdx, %rsi
	cmpl	$5, %eax
	movq	%r8, %rbx
	je	.L291
	cmpl	$20, %eax
	je	.L292
	cmpl	$4, %eax
	je	.L300
	movq	%rbx, %rdx
	movl	$4, %r8d
	call	luaT_gettmbyobj
	movq	%rax, %rdx
	movl	8(%rax), %eax
	testl	%eax, %eax
	je	.L301
.L297:
	movq	%rsi, 32(%rsp)
	movq	%rbx, %r9
	movq	%rbx, %r8
	movq	%rdi, %rcx
	movl	$1, 40(%rsp)
	call	luaT_callTM
	nop
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L300:
	movq	(%r8), %rax
	movzbl	11(%rax), %eax
	movl	$19, 8(%rdx)
	movq	%rax, (%rdx)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L292:
	movq	(%r8), %rax
	movq	16(%rax), %rax
	movl	$19, 8(%rdx)
	movq	%rax, (%rdx)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L291:
	movq	(%r8), %rbp
	movq	40(%rbp), %rcx
	testq	%rcx, %rcx
	je	.L296
	testb	$16, 10(%rcx)
	je	.L302
.L296:
	movq	%rbp, %rcx
	call	luaH_getn
	movl	$19, 8(%rsi)
	cltq
	movq	%rax, (%rsi)
	addq	$56, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	ret
	.p2align 4,,10
.L302:
	movq	24(%rdi), %rdx
	movq	256(%rdx), %r8
	movl	$4, %edx
	call	luaT_gettm
	testq	%rax, %rax
	movq	%rax, %rdx
	jne	.L297
	jmp	.L296
.L301:
	leaq	.LC19(%rip), %r8
	movq	%rbx, %rdx
	movq	%rdi, %rcx
	call	luaG_typeerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE20:
	.text
.LHOTE20:
	.section .rdata,"dr"
.LC21:
	.ascii "attempt to divide by zero\0"
	.section	.text.unlikely,"x"
.LCOLDB22:
	.text
.LHOTB22:
	.p2align 4,,15
	.globl	luaV_div
	.def	luaV_div;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_div
luaV_div:
	subq	$40, %rsp
	.seh_stackalloc	40
	.seh_endprologue
	leaq	1(%r8), %rax
	movq	%rdx, %r9
	cmpq	$1, %rax
	jbe	.L310
	movq	%rdx, %rax
	cqto
	idivq	%r8
	xorq	%r9, %r8
	js	.L311
	addq	$40, %rsp
	ret
	.p2align 4,,10
.L310:
	testq	%r8, %r8
	je	.L312
	movq	%rdx, %rax
	negq	%rax
	addq	$40, %rsp
	ret
	.p2align 4,,10
.L311:
	cmpq	$1, %rdx
	adcq	$-1, %rax
	addq	$40, %rsp
	ret
.L312:
	leaq	.LC21(%rip), %rdx
	call	luaG_runerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE22:
	.text
.LHOTE22:
	.section .rdata,"dr"
.LC23:
	.ascii "attempt to perform 'n%%0'\0"
	.section	.text.unlikely,"x"
.LCOLDB24:
	.text
.LHOTB24:
	.p2align 4,,15
	.globl	luaV_mod
	.def	luaV_mod;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_mod
luaV_mod:
	subq	$40, %rsp
	.seh_stackalloc	40
	.seh_endprologue
	leaq	1(%r8), %rax
	movq	%rdx, %r9
	cmpq	$1, %rax
	jbe	.L320
	movq	%rdx, %rax
	cqto
	idivq	%r8
	xorl	%eax, %eax
	testq	%rdx, %rdx
	je	.L315
	xorq	%r8, %r9
	movq	%rdx, %rax
	js	.L321
.L315:
	addq	$40, %rsp
	ret
	.p2align 4,,10
.L320:
	testq	%r8, %r8
	je	.L322
	xorl	%eax, %eax
	addq	$40, %rsp
	ret
	.p2align 4,,10
.L321:
	addq	%r8, %rax
	jmp	.L315
.L322:
	leaq	.LC23(%rip), %rdx
	call	luaG_runerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE24:
	.text
.LHOTE24:
	.section	.text.unlikely,"x"
.LCOLDB25:
	.text
.LHOTB25:
	.p2align 4,,15
	.globl	luaV_shiftl
	.def	luaV_shiftl;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_shiftl
luaV_shiftl:
	.seh_endprologue
	testq	%rdx, %rdx
	movq	%rcx, %r8
	js	.L328
	movl	%edx, %ecx
	salq	%cl, %r8
	cmpq	$63, %rdx
	movl	$0, %edx
	movq	%rdx, %rax
	cmovle	%r8, %rax
.L325:
	ret
	.p2align 4,,10
.L328:
	xorl	%eax, %eax
	cmpq	$-63, %rdx
	jl	.L325
	movl	%edx, %ecx
	movq	%r8, %rax
	negl	%ecx
	shrq	%cl, %rax
	ret
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE25:
	.text
.LHOTE25:
	.section	.text.unlikely,"x"
.LCOLDB26:
	.text
.LHOTB26:
	.p2align 4,,15
	.globl	luaV_finishOp
	.def	luaV_finishOp;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_finishOp
luaV_finishOp:
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$32, %rsp
	.seh_stackalloc	32
	.seh_endprologue
	movq	32(%rcx), %rsi
	movq	40(%rsi), %rax
	movq	32(%rsi), %r8
	movl	-4(%rax), %ebx
	movl	%ebx, %eax
	andl	$63, %eax
	subl	$6, %eax
	cmpl	$35, %eax
	ja	.L329
	leaq	.L332(%rip), %rdx
	movslq	(%rdx,%rax,4), %rax
	addq	%rax, %rdx
	jmp	*%rdx
	.section .rdata,"dr"
	.align 4
.L332:
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L331-.L332
	.long	.L329-.L332
	.long	.L331-.L332
	.long	.L333-.L332
	.long	.L329-.L332
	.long	.L334-.L332
	.long	.L334-.L332
	.long	.L334-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L335-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L329-.L332
	.long	.L352-.L332
	.text
	.p2align 4,,10
.L334:
	movq	16(%rcx), %rax
	xorl	%edx, %edx
	movl	-8(%rax), %r8d
	testl	%r8d, %r8d
	je	.L337
	cmpl	$1, %r8d
	movb	$1, %dl
	je	.L353
.L337:
	subq	$16, %rax
	movq	%rax, 16(%rcx)
	movzwl	66(%rsi), %eax
	testb	$-128, %al
	je	.L338
	xorb	$-128, %al
	xorl	$1, %edx
	movw	%ax, 66(%rsi)
.L338:
	shrl	$6, %ebx
	movzbl	%bl, %ebx
	cmpl	%edx, %ebx
	je	.L329
	addq	$4, 40(%rsi)
.L329:
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L335:
	andl	$8372224, %ebx
	je	.L329
.L352:
	movq	8(%rsi), %rax
	movq	%rax, 16(%rcx)
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L331:
	movq	16(%rcx), %rax
	shrl	$6, %ebx
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	-16(%rax), %rdx
	movq	%rdx, 16(%rcx)
	movq	-8(%rax), %rdx
	movq	-16(%rax), %rax
	movq	%rdx, 8(%r8,%rbx)
	movq	%rax, (%r8,%rbx)
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L333:
	movq	16(%rcx), %rax
	movl	%ebx, %edx
	movq	%rcx, %rdi
	shrl	$23, %edx
	salq	$4, %rdx
	movq	%rax, %rcx
	movq	-16(%rax), %r9
	subq	%r8, %rcx
	movq	-8(%rax), %r10
	subq	%rdx, %rcx
	movq	%rcx, %rdx
	subq	$32, %rdx
	movq	%r9, -48(%rax)
	sarq	$4, %rdx
	movq	%r10, -40(%rax)
	cmpl	$1, %edx
	jle	.L340
	subq	$32, %rax
	movq	%rdi, %rcx
	movq	%rax, 16(%rdi)
	call	luaV_concat
	movq	32(%rsi), %r8
	movq	16(%rdi), %rax
.L340:
	movq	-8(%rax), %rdx
	shrl	$6, %ebx
	movq	-16(%rax), %rax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	movq	%rdx, 8(%r8,%rbx)
	movq	%rax, (%r8,%rbx)
	movq	8(%rsi), %rax
	movq	%rax, 16(%rdi)
	addq	$32, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	ret
	.p2align 4,,10
.L353:
	movl	-16(%rax), %r8d
	xorl	%edx, %edx
	testl	%r8d, %r8d
	setne	%dl
	jmp	.L337
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE26:
	.text
.LHOTE26:
	.section .rdata,"dr"
.LC29:
	.ascii "'for' limit must be a number\0"
.LC30:
	.ascii "'for' step must be a number\0"
	.align 8
.LC31:
	.ascii "'for' initial value must be a number\0"
	.section	.text.unlikely,"x"
.LCOLDB32:
	.text
.LHOTB32:
	.p2align 4,,15
	.globl	luaV_execute
	.def	luaV_execute;	.scl	2;	.type	32;	.endef
	.seh_proc	luaV_execute
luaV_execute:
	pushq	%r15
	.seh_pushreg	%r15
	pushq	%r14
	.seh_pushreg	%r14
	pushq	%r13
	.seh_pushreg	%r13
	pushq	%r12
	.seh_pushreg	%r12
	pushq	%rbp
	.seh_pushreg	%rbp
	pushq	%rdi
	.seh_pushreg	%rdi
	pushq	%rsi
	.seh_pushreg	%rsi
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$216, %rsp
	.seh_stackalloc	216
	movaps	%xmm6, 144(%rsp)
	.seh_savexmm	%xmm6, 144
	movaps	%xmm7, 160(%rsp)
	.seh_savexmm	%xmm7, 160
	movaps	%xmm8, 176(%rsp)
	.seh_savexmm	%xmm8, 176
	movaps	%xmm9, 192(%rsp)
	.seh_savexmm	%xmm9, 192
	.seh_endprologue
	pxor	%xmm9, %xmm9
	movapd	%xmm9, %xmm6
	movapd	%xmm9, %xmm7
	movsd	.LC28(%rip), %xmm8
	leaq	.L360(%rip), %r13
	movq	32(%rcx), %rbp
	orw	$8, 66(%rbp)
	movq	%rcx, %r14
	.p2align 4,,10
.L355:
	movq	0(%rbp), %rax
	movq	32(%rbp), %rdi
	leaq	120(%rsp), %rcx
	movq	%rcx, 80(%rsp)
	leaq	136(%rsp), %rcx
	movq	%rcx, 64(%rsp)
	movq	(%rax), %rax
	movq	%rax, 56(%rsp)
	movq	24(%rax), %rax
	movq	24(%rax), %r12
	movq	40(%rbp), %rax
	.p2align 4,,10
.L356:
	leaq	4(%rax), %rdx
	movq	%rdx, 40(%rbp)
	testb	$12, 200(%r14)
	movl	(%rax), %ebx
	jne	.L932
.L358:
	movl	%ebx, %r15d
	movl	%ebx, %eax
	shrl	$6, %r15d
	andl	$63, %eax
	movzbl	%r15b, %edx
	movq	%rdx, %r9
	movq	%rdx, %r15
	salq	$4, %r9
	cmpl	$45, %eax
	leaq	(%rdi,%r9), %rsi
	ja	.L357
	movslq	0(%r13,%rax,4), %rax
	addq	%r13, %rax
	jmp	*%rax
	.section .rdata,"dr"
	.align 4
.L360:
	.long	.L359-.L360
	.long	.L361-.L360
	.long	.L362-.L360
	.long	.L363-.L360
	.long	.L364-.L360
	.long	.L365-.L360
	.long	.L366-.L360
	.long	.L367-.L360
	.long	.L368-.L360
	.long	.L369-.L360
	.long	.L370-.L360
	.long	.L371-.L360
	.long	.L372-.L360
	.long	.L373-.L360
	.long	.L374-.L360
	.long	.L375-.L360
	.long	.L376-.L360
	.long	.L377-.L360
	.long	.L378-.L360
	.long	.L379-.L360
	.long	.L380-.L360
	.long	.L381-.L360
	.long	.L382-.L360
	.long	.L383-.L360
	.long	.L384-.L360
	.long	.L385-.L360
	.long	.L386-.L360
	.long	.L387-.L360
	.long	.L388-.L360
	.long	.L389-.L360
	.long	.L390-.L360
	.long	.L391-.L360
	.long	.L392-.L360
	.long	.L393-.L360
	.long	.L394-.L360
	.long	.L395-.L360
	.long	.L396-.L360
	.long	.L397-.L360
	.long	.L398-.L360
	.long	.L399-.L360
	.long	.L400-.L360
	.long	.L401-.L360
	.long	.L402-.L360
	.long	.L403-.L360
	.long	.L404-.L360
	.long	.L405-.L360
	.text
	.p2align 4,,10
.L401:
	movq	32(%rsi), %rax
	shrl	$14, %ebx
	movq	%r14, %rcx
	movq	40(%rsi), %rdx
	movl	%ebx, %r8d
	andl	$511, %r8d
	movq	%rax, 80(%rsi)
	movq	16(%rsi), %rax
	movq	%rdx, 88(%rsi)
	movq	24(%rsi), %rdx
	movq	%rax, 64(%rsi)
	movq	(%rsi), %rax
	movq	%rdx, 72(%rsi)
	movq	8(%rsi), %rdx
	movq	%rax, 48(%rsi)
	leaq	96(%rsi), %rax
	movq	%rdx, 56(%rsi)
	leaq	48(%rsi), %rdx
	movq	%rax, 16(%r14)
	call	luaD_call
	movq	8(%rbp), %rax
	movq	32(%rbp), %rdi
	movq	%rax, 16(%r14)
	movq	40(%rbp), %rax
	leaq	4(%rax), %rdx
	movq	%rdx, 40(%rbp)
	movl	(%rax), %ebx
	movl	%ebx, %esi
	shrl	$6, %esi
	movzbl	%sil, %esi
	salq	$4, %rsi
	addq	%rdi, %rsi
.L402:
	movq	skynet_sig_L(%rip), %rax
	testq	%rax, %rax
	je	.L658
	movq	24(%r14), %rdx
	cmpq	200(%rdx), %rax
	je	.L933
.L658:
	movl	24(%rsi), %eax
	testl	%eax, %eax
	je	.L357
	movq	16(%rsi), %rax
	shrl	$14, %ebx
	movq	24(%rsi), %rdx
	movslq	%ebx, %rbx
	movq	%rax, (%rsi)
	movq	%rdx, 8(%rsi)
	movq	40(%rbp), %rax
	leaq	-524284(%rax,%rbx,4), %rax
	movq	%rax, 40(%rbp)
	jmp	.L356
	.p2align 4,,10
.L394:
	andl	$8372224, %ebx
	movl	8(%rsi), %eax
	je	.L600
	testl	%eax, %eax
	je	.L825
	cmpl	$1, %eax
	je	.L934
	.p2align 4,,10
.L918:
	movq	40(%rbp), %rdx
	movl	(%rdx), %ebx
	movl	%ebx, %eax
	shrl	$6, %eax
	movzbl	%al, %eax
	testl	%eax, %eax
	jne	.L935
.L611:
	shrl	$14, %ebx
	leal	-131071(%rbx), %eax
	cltq
	leaq	4(%rdx,%rax,4), %rax
	movq	%rax, 40(%rbp)
	jmp	.L356
	.p2align 4,,10
.L393:
	movl	%ebx, %eax
	shrl	$14, %eax
	testb	$1, %ah
	je	.L593
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r8
.L594:
	shrl	$23, %ebx
	testb	$1, %bh
	je	.L595
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	(%r12,%rbx), %rdx
.L596:
	movq	%r14, %rcx
	call	luaV_lessequal
	cmpl	%eax, %r15d
	je	.L597
.L905:
	movq	40(%rbp), %rax
	addq	$4, %rax
	movq	%rax, 40(%rbp)
.L598:
	movq	32(%rbp), %rdi
	jmp	.L356
	.p2align 4,,10
.L392:
	movl	%ebx, %eax
	shrl	$14, %eax
	testb	$1, %ah
	je	.L586
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r8
.L587:
	shrl	$23, %ebx
	testb	$1, %bh
	je	.L588
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	(%r12,%rbx), %rdx
.L589:
	movq	%r14, %rcx
	call	luaV_lessthan
	cmpl	%eax, %r15d
	jne	.L905
.L597:
	movq	40(%rbp), %rdx
	movl	(%rdx), %ebx
	movl	%ebx, %eax
	shrl	$6, %eax
	movzbl	%al, %eax
	testl	%eax, %eax
	jne	.L936
.L599:
	shrl	$14, %ebx
	leal	-131071(%rbx), %eax
	cltq
	leaq	4(%rdx,%rax,4), %rax
	movq	%rax, 40(%rbp)
	jmp	.L598
	.p2align 4,,10
.L398:
	movq	56(%rsp), %rax
	shrl	$23, %ebx
	movq	24(%rax), %rax
	movq	16(%rax), %rax
	movl	20(%rax), %edx
	testl	%edx, %edx
	jle	.L624
	movq	%rdi, %rdx
	movq	%r14, %rcx
	call	luaF_close
.L624:
	leal	-1(%rbx), %r9d
	testl	%ebx, %ebx
	jne	.L626
	movq	16(%r14), %rbx
	subq	%rsi, %rbx
	shrq	$4, %rbx
	movq	%rbx, %r9
.L626:
	movq	%rsi, %r8
	movq	%rbp, %rdx
	movq	%r14, %rcx
	call	luaD_poscall
	testb	$8, 66(%rbp)
	jne	.L354
	testl	%eax, %eax
	movq	32(%r14), %rbp
	je	.L355
	movq	8(%rbp), %rax
	movq	%rax, 16(%r14)
	jmp	.L355
	.p2align 4,,10
.L397:
	movq	skynet_sig_L(%rip), %rax
	shrl	$23, %ebx
	testq	%rax, %rax
	je	.L617
	movq	24(%r14), %rdx
	cmpq	200(%rdx), %rax
	je	.L937
.L617:
	testl	%ebx, %ebx
	je	.L618
	salq	$4, %rbx
	leaq	(%rsi,%rbx), %rax
	movq	%rax, 16(%r14)
.L618:
	movl	$-1, %r8d
	movq	%rsi, %rdx
	movq	%r14, %rcx
	call	luaD_precall
	testl	%eax, %eax
	je	.L938
.L899:
	movq	32(%rbp), %rdi
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L390:
	movq	skynet_sig_L(%rip), %rax
	testq	%rax, %rax
	je	.L577
	movq	24(%r14), %rdx
	cmpq	200(%rdx), %rax
	je	.L939
.L577:
	testl	%r15d, %r15d
	jne	.L940
.L578:
	movq	40(%rbp), %rdx
	shrl	$14, %ebx
	leal	-131071(%rbx), %eax
	cltq
	leaq	(%rdx,%rax,4), %rax
	movq	%rax, 40(%rbp)
	jmp	.L356
	.p2align 4,,10
.L400:
	cmpl	$19, 8(%rsi)
	leaq	16(%rsi), %r15
	je	.L941
.L637:
	cmpl	$3, 24(%rsi)
	jne	.L649
	movsd	16(%rsi), %xmm0
	movsd	%xmm0, 128(%rsp)
.L650:
	cmpl	$3, 40(%rsi)
	movsd	%xmm0, 16(%rsi)
	movl	$3, 24(%rsi)
	jne	.L652
	movsd	32(%rsi), %xmm1
	movsd	%xmm1, 136(%rsp)
.L653:
	cmpl	$3, 8(%rsi)
	movsd	%xmm1, 32(%rsi)
	movl	$3, 40(%rsi)
	jne	.L655
	movsd	(%rsi), %xmm0
.L656:
	subsd	%xmm1, %xmm0
	movl	$3, 8(%rsi)
	movsd	%xmm0, (%rsi)
.L648:
	movq	40(%rbp), %rax
	shrl	$14, %ebx
	leaq	-524284(%rax,%rbx,4), %rax
	movq	%rax, 40(%rbp)
	jmp	.L356
	.p2align 4,,10
.L391:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L579
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %rdx
.L580:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L581
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	(%r12,%rbx), %r8
.L582:
	movq	%r14, %rcx
	call	luaV_equalobj
	cmpl	%eax, %r15d
	jne	.L905
	jmp	.L597
	.p2align 4,,10
.L396:
	movq	skynet_sig_L(%rip), %rax
	movl	%ebx, %edi
	shrl	$14, %ebx
	andl	$511, %ebx
	shrl	$23, %edi
	subl	$1, %ebx
	testq	%rax, %rax
	je	.L612
	movq	24(%r14), %rdx
	cmpq	200(%rdx), %rax
	je	.L942
.L612:
	testl	%edi, %edi
	je	.L613
	salq	$4, %rdi
	leaq	(%rsi,%rdi), %rax
	movq	%rax, 16(%r14)
.L613:
	movl	%ebx, %r8d
	movq	%rsi, %rdx
	movq	%r14, %rcx
	call	luaD_precall
	testl	%eax, %eax
	je	.L614
	cmpl	$-1, %ebx
	je	.L899
	movq	8(%rbp), %rax
	movq	%rax, 16(%r14)
	jmp	.L899
	.p2align 4,,10
.L395:
	movl	%ebx, %eax
	shrl	$23, %eax
	salq	$4, %rax
	addq	%rdi, %rax
	andl	$8372224, %ebx
	movl	8(%rax), %edx
	je	.L606
	testl	%edx, %edx
	je	.L825
	cmpl	$1, %edx
	je	.L943
	.p2align 4,,10
.L610:
	movq	8(%rax), %rdx
	movq	(%rax), %rax
	movq	%rdx, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L918
	.p2align 4,,10
.L388:
	shrl	$23, %ebx
	movq	%rsi, %rdx
	movq	%r14, %rcx
	movl	%ebx, %r8d
	salq	$4, %r8
	addq	%rdi, %r8
	call	luaV_objlen
	movq	32(%rbp), %rdi
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L387:
	shrl	$23, %ebx
	movl	$1, %edx
	movl	%ebx, %eax
	salq	$4, %rax
	addq	%rdi, %rax
	movl	8(%rax), %ecx
	testl	%ecx, %ecx
	je	.L574
	xorb	%dl, %dl
	cmpl	$1, %ecx
	je	.L944
.L574:
	movl	%edx, (%rsi)
	movl	$1, 8(%rsi)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L399:
	movq	skynet_sig_L(%rip), %rax
	testq	%rax, %rax
	je	.L628
	movq	24(%r14), %rdx
	cmpq	200(%rdx), %rax
	je	.L945
.L628:
	cmpl	$19, 8(%rsi)
	je	.L946
	movsd	32(%rsi), %xmm0
	movsd	(%rsi), %xmm1
	ucomisd	%xmm6, %xmm0
	movsd	16(%rsi), %xmm2
	addsd	%xmm0, %xmm1
	jbe	.L894
	ucomisd	%xmm1, %xmm2
	setae	%al
.L635:
	testb	%al, %al
	je	.L357
	movq	40(%rbp), %rdx
	shrl	$14, %ebx
	movl	%ebx, %eax
	leaq	-524284(%rdx,%rax,4), %rax
	movq	%rax, 40(%rbp)
	movsd	%xmm1, (%rsi)
	movsd	%xmm1, 48(%rsi)
	movl	$3, 56(%rsi)
	jmp	.L356
	.p2align 4,,10
.L389:
	movl	%ebx, %esi
	shrl	$14, %ebx
	movq	%r14, %rcx
	movq	%r9, 72(%rsp)
	andl	$511, %ebx
	shrl	$23, %esi
	movslq	%ebx, %rax
	subl	%esi, %ebx
	salq	$4, %rsi
	leal	1(%rbx), %edx
	addq	$1, %rax
	salq	$4, %rax
	addq	%rax, %rdi
	movq	%rdi, 16(%r14)
	call	luaV_concat
	movq	32(%rbp), %rdi
	movq	72(%rsp), %r9
	movq	24(%r14), %rdx
	leaq	(%rdi,%rsi), %rax
	addq	%rdi, %r9
	movq	(%rax), %rcx
	movq	8(%rax), %rbx
	cmpq	$0, 24(%rdx)
	movq	%rcx, (%r9)
	movq	%rbx, 8(%r9)
	jle	.L667
	leaq	16(%r9), %rdx
	cmpq	%rax, %r9
	movq	%r14, %rcx
	cmovae	%rdx, %rax
	movq	%rax, 16(%r14)
	call	luaC_step
	movq	8(%rbp), %rax
	movq	%rax, 16(%r14)
	movq	32(%rbp), %rdi
.L901:
	movq	%rax, 16(%r14)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L386:
	shrl	$23, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, 8(%rbx)
	jne	.L570
	movq	(%rbx), %rax
.L571:
	notq	%rax
.L910:
	movq	%rax, (%rsi)
	movl	$19, 8(%rsi)
	.p2align 4,,10
.L357:
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L370:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L423
.L931:
	movzbl	%al, %eax
	shrl	$14, %ebx
	salq	$4, %rax
	testb	$1, %bh
	leaq	(%r12,%rax), %r8
	je	.L425
.L948:
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	(%r12,%rbx), %r9
	xorl	%ebx, %ebx
	cmpl	$69, 8(%rsi)
	je	.L947
.L427:
	movq	%rbx, 32(%rsp)
	movq	%rsi, %rdx
	movq	%r14, %rcx
	call	luaV_finishset
	jmp	.L899
	.p2align 4,,10
.L369:
	movq	56(%rsp), %rax
	shrl	$23, %ebx
	movslq	%ebx, %rbx
	movq	(%rsi), %rcx
	movq	32(%rax,%rbx,8), %rdx
	movq	8(%rsi), %rbx
	movq	(%rdx), %rax
	movq	%rbx, 8(%rax)
	testb	$64, 8(%rax)
	movq	%rcx, (%rax)
	je	.L357
	leaq	16(%rdx), %rcx
	cmpq	%rcx, %rax
	jne	.L357
	movq	%r14, %rcx
	call	luaC_upvalbarrier_
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L368:
	movq	56(%rsp), %rax
	movq	32(%rax,%rdx,8), %rax
	movq	(%rax), %rsi
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	jne	.L931
.L423:
	cltq
	shrl	$14, %ebx
	salq	$4, %rax
	testb	$1, %bh
	leaq	(%rdi,%rax), %r8
	jne	.L948
.L425:
	andl	$511, %ebx
	salq	$4, %rbx
	leaq	(%rdi,%rbx), %r9
	xorl	%ebx, %ebx
	cmpl	$69, 8(%rsi)
	jne	.L427
.L947:
	movq	%r9, 88(%rsp)
	movq	%r8, %rdx
	movq	%r8, 72(%rsp)
	movq	(%rsi), %rcx
	call	luaH_get
	movq	72(%rsp), %r8
	movl	8(%rax), %ecx
	movq	%rax, %rbx
	movq	88(%rsp), %r9
	testl	%ecx, %ecx
	je	.L427
	testb	$64, 8(%r9)
	je	.L428
	movq	(%rsi), %rdx
	testb	$4, 9(%rdx)
	je	.L428
	movq	(%r9), %rax
	testb	$3, 9(%rax)
	jne	.L949
.L428:
	movq	(%r9), %rax
	movq	8(%r9), %rdx
	movq	%rax, (%rbx)
	movq	%rdx, 8(%rbx)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L378:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L467
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L468:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L469
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L470:
	cmpl	$3, 8(%r15)
	jne	.L471
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L472:
	cmpl	$3, 8(%rbx)
	jne	.L474
	movsd	(%rbx), %xmm1
.L475:
	movsd	128(%rsp), %xmm0
	movl	$3, 8(%rsi)
	divsd	%xmm1, %xmm0
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L377:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L555
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L556:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L557
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L558:
	cmpl	$3, 8(%r15)
	jne	.L559
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L560:
	cmpl	$3, 8(%rbx)
	jne	.L562
	movsd	(%rbx), %xmm1
	movsd	%xmm1, 136(%rsp)
.L563:
	movsd	128(%rsp), %xmm0
	call	pow
	movl	$3, 8(%rsi)
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L376:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L531
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L532:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L533
	movl	8(%r15), %eax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
	cmpl	$19, %eax
	je	.L950
.L535:
	cmpl	$3, %eax
	jne	.L536
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L538:
	cmpl	$3, 8(%rbx)
	jne	.L540
	movsd	(%rbx), %xmm1
	movsd	%xmm1, 136(%rsp)
.L541:
	movsd	128(%rsp), %xmm0
	call	fmod
	movsd	136(%rsp), %xmm1
	movapd	%xmm0, %xmm2
	mulsd	%xmm1, %xmm2
	ucomisd	%xmm2, %xmm7
	ja	.L951
.L909:
	movsd	%xmm0, (%rsi)
	movl	$3, 8(%rsi)
	jmp	.L357
	.p2align 4,,10
.L375:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L456
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L457:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L458
	movl	8(%r15), %eax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
	cmpl	$19, %eax
	je	.L952
.L460:
	cmpl	$3, %eax
	jne	.L461
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L463:
	cmpl	$3, 8(%rbx)
	jne	.L465
	movsd	(%rbx), %xmm0
.L466:
	mulsd	128(%rsp), %xmm0
	movl	$3, 8(%rsi)
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L367:
	movl	%ebx, %r15d
	shrl	$14, %ebx
	shrl	$23, %r15d
	salq	$4, %r15
	addq	%rdi, %r15
	testb	$1, %bh
	je	.L412
.L911:
	movzbl	%bl, %ebx
	xorl	%eax, %eax
	salq	$4, %rbx
	cmpl	$69, 8(%r15)
	leaq	(%r12,%rbx), %r8
	je	.L953
.L433:
	movq	%rax, 32(%rsp)
	movq	%rsi, %r9
	movq	%r15, %rdx
	movq	%r14, %rcx
	call	luaV_finishget
	movq	32(%rbp), %rdi
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L362:
	movq	40(%rbp), %rdx
	leaq	4(%rdx), %rax
	movq	%rax, 40(%rbp)
	movl	(%rdx), %edx
	shrl	$6, %edx
	movslq	%edx, %rdx
	salq	$4, %rdx
	movq	(%r12,%rdx), %rcx
	movq	8(%r12,%rdx), %rbx
	movq	%rcx, (%rsi)
	movq	%rbx, 8(%rsi)
	jmp	.L356
	.p2align 4,,10
.L361:
	shrl	$14, %ebx
	salq	$4, %rbx
	movq	(%r12,%rbx), %rax
	movq	8(%r12,%rbx), %rdx
	movq	%rax, (%rsi)
	movq	%rdx, 8(%rsi)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L404:
	movq	56(%rsp), %rcx
	shrl	$14, %ebx
	movq	24(%rcx), %rax
	leaq	32(%rcx), %r8
	movq	32(%rax), %rax
	movq	(%rax,%rbx,8), %r9
	movq	40(%r9), %r10
	movq	16(%r9), %rax
	testq	%r10, %r10
	je	.L668
	movl	4(%rax), %ebx
	movq	72(%rax), %r15
	testl	%ebx, %ebx
	jle	.L669
	addq	$9, %r15
	xorl	%edx, %edx
	movq	%r15, %rax
	jmp	.L673
	.p2align 4,,10
.L954:
	movq	32(%r10,%rdx,8), %r11
	salq	$4, %rcx
	addq	%rdi, %rcx
	cmpq	%rcx, (%r11)
	jne	.L672
.L955:
	addq	$1, %rdx
	addq	$16, %rax
	cmpl	%edx, %ebx
	jle	.L669
.L673:
	cmpb	$0, -1(%rax)
	movzbl	(%rax), %ecx
	jne	.L954
	movq	(%r8,%rcx,8), %rcx
	movq	32(%r10,%rdx,8), %r11
	movq	(%rcx), %rcx
	cmpq	%rcx, (%r11)
	je	.L955
.L672:
	movl	%ebx, %edx
	movq	%r14, %rcx
	movq	%r9, 88(%rsp)
	movq	%r8, 72(%rsp)
	call	luaF_newLclosure
	movq	88(%rsp), %r9
	movq	72(%rsp), %r8
	movq	%rax, %r10
	movq	%r9, 24(%rax)
	movq	%rax, (%rsi)
	movl	$70, 8(%rsi)
.L686:
	movq	%r15, %r11
	movq	%rsi, 72(%rsp)
	xorl	%r15d, %r15d
	movl	%ebx, %esi
	movq	%r12, 88(%rsp)
	movq	%r10, %rbx
	movq	%r11, %r12
	movq	%rbp, 104(%rsp)
	movq	%r8, %rbp
	movq	%r9, 96(%rsp)
	jmp	.L676
	.p2align 4,,10
.L674:
	movzbl	(%r12), %eax
	movq	0(%rbp,%rax,8), %rax
	movq	%rax, 32(%rbx,%r15,8)
.L675:
	addq	$1, 8(%rax)
	addq	$1, %r15
	addq	$16, %r12
	cmpl	%r15d, %esi
	jle	.L956
.L676:
	cmpb	$0, -1(%r12)
	je	.L674
	movzbl	(%r12), %edx
	movq	%r14, %rcx
	salq	$4, %rdx
	addq	%rdi, %rdx
	call	luaF_findupval
	movq	%rax, 32(%rbx,%r15,8)
	jmp	.L675
	.p2align 4,,10
.L403:
	movl	%ebx, %r9d
	shrl	$14, %ebx
	shrl	$23, %r9d
	andl	$511, %ebx
	testl	%r9d, %r9d
	jne	.L661
	movq	16(%r14), %r9
	subq	%rsi, %r9
	sarq	$4, %r9
	subl	$1, %r9d
.L661:
	testl	%ebx, %ebx
	jne	.L662
	movq	40(%rbp), %rax
	leaq	4(%rax), %rdx
	movq	%rdx, 40(%rbp)
	movl	(%rax), %ebx
	shrl	$6, %ebx
.L662:
	movq	(%rsi), %r15
	leal	-1(%rbx), %eax
	imull	$50, %eax, %eax
	addl	%r9d, %eax
	cmpl	12(%r15), %eax
	ja	.L957
.L663:
	testl	%r9d, %r9d
	jle	.L667
	movslq	%r9d, %r10
	movl	%eax, %ecx
	movq	%rdi, 72(%rsp)
	movl	%eax, %r8d
	salq	$4, %r10
	subl	%r9d, %ecx
	addq	%r10, %rsi
	movq	%rsi, %rdi
	movl	%ecx, %esi
	.p2align 4,,10
.L666:
	movq	%rdi, %r9
	movq	%r15, %rdx
	movq	%r14, %rcx
	leal	-1(%r8), %ebx
	call	luaH_setint
	testb	$64, 8(%rdi)
	je	.L665
	testb	$4, 9(%r15)
	je	.L665
	movq	(%rdi), %rax
	testb	$3, 9(%rax)
	jne	.L958
	.p2align 4,,10
.L665:
	movl	%ebx, %r8d
	subq	$16, %rdi
	cmpl	%esi, %r8d
	jne	.L666
	movq	72(%rsp), %rdi
.L667:
	movq	8(%rbp), %rax
	jmp	.L901
	.p2align 4,,10
.L359:
	shrl	$23, %ebx
	salq	$4, %rbx
	movq	(%rdi,%rbx), %rax
	movq	8(%rdi,%rbx), %rdx
	movq	%rax, (%rsi)
	movq	%rdx, 8(%rsi)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L382:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L497
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L498:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L499
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L500:
	cmpl	$19, 8(%r15)
	jne	.L501
	movq	(%r15), %rax
	movq	%rax, 128(%rsp)
.L502:
	cmpl	$19, 8(%rbx)
	jne	.L504
	movq	(%rbx), %rax
.L505:
	xorq	128(%rsp), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L381:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L487
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L488:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L489
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L490:
	cmpl	$19, 8(%r15)
	jne	.L491
	movq	(%r15), %rax
	movq	%rax, 128(%rsp)
.L492:
	cmpl	$19, 8(%rbx)
	jne	.L494
	movq	(%rbx), %rax
.L495:
	orq	128(%rsp), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L380:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L477
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L478:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L479
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L480:
	cmpl	$19, 8(%r15)
	jne	.L481
	movq	(%r15), %rax
	movq	%rax, 128(%rsp)
.L482:
	cmpl	$19, 8(%rbx)
	jne	.L484
	movq	(%rbx), %rax
.L485:
	andq	128(%rsp), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L379:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L544
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L545:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L546
	movl	8(%r15), %eax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
	cmpl	$19, %eax
	je	.L959
.L548:
	cmpl	$3, %eax
	jne	.L549
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L551:
	cmpl	$3, 8(%rbx)
	jne	.L553
	movsd	(%rbx), %xmm1
.L554:
	movsd	128(%rsp), %xmm0
	divsd	%xmm1, %xmm0
	call	floor
	movl	$3, 8(%rsi)
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L366:
	movq	56(%rsp), %rcx
	movl	%ebx, %eax
	shrl	$14, %ebx
	shrl	$23, %eax
	testb	$1, %bh
	cltq
	movq	32(%rcx,%rax,8), %rax
	movq	(%rax), %r15
	jne	.L911
.L412:
	andl	$511, %ebx
	xorl	%eax, %eax
	salq	$4, %rbx
	cmpl	$69, 8(%r15)
	leaq	(%rdi,%rbx), %r8
	jne	.L433
.L953:
	movq	%r8, 72(%rsp)
	movq	(%r15), %rcx
	movq	%r8, %rdx
	call	luaH_get
	movl	8(%rax), %r8d
	testl	%r8d, %r8d
	movq	72(%rsp), %r8
	jne	.L900
	jmp	.L433
	.p2align 4,,10
.L374:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L445
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L446:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L447
	movl	8(%r15), %eax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
	cmpl	$19, %eax
	je	.L960
.L449:
	cmpl	$3, %eax
	jne	.L450
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L452:
	cmpl	$3, 8(%rbx)
	jne	.L454
	movsd	(%rbx), %xmm1
.L455:
	movsd	128(%rsp), %xmm0
	movl	$3, 8(%rsi)
	subsd	%xmm1, %xmm0
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L373:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L434
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L435:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L436
	movl	8(%r15), %eax
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
	cmpl	$19, %eax
	je	.L961
.L438:
	cmpl	$3, %eax
	jne	.L439
	movsd	(%r15), %xmm0
	movsd	%xmm0, 128(%rsp)
.L441:
	cmpl	$3, 8(%rbx)
	jne	.L443
	movsd	(%rbx), %xmm0
.L444:
	addsd	128(%rsp), %xmm0
	movl	$3, 8(%rsi)
	movsd	%xmm0, (%rsi)
	jmp	.L357
	.p2align 4,,10
.L372:
	movl	%ebx, %r15d
	shrl	$14, %ebx
	shrl	$23, %r15d
	salq	$4, %r15
	addq	%rdi, %r15
	testb	$1, %bh
	je	.L431
	movzbl	%bl, %ebx
	salq	$4, %rbx
	leaq	(%r12,%rbx), %r8
.L432:
	movq	(%r15), %rcx
	xorl	%eax, %eax
	movq	8(%r15), %rbx
	movq	(%r8), %rdx
	movq	%rcx, 16(%rsi)
	movq	%rbx, 24(%rsi)
	cmpl	$69, 8(%r15)
	jne	.L433
	movq	(%r15), %rcx
	movq	%r8, 72(%rsp)
	call	luaH_getstr
	movq	72(%rsp), %r8
	movl	8(%rax), %edx
	testl	%edx, %edx
	jne	.L900
	jmp	.L433
	.p2align 4,,10
.L405:
	movq	56(%rsp), %rax
	movq	%rdi, %r15
	shrl	$23, %ebx
	subq	0(%rbp), %r15
	subl	$1, %ebx
	movq	24(%rax), %rax
	sarq	$4, %r15
	movq	16(%rax), %rax
	movzbl	(%rax), %eax
	subl	%eax, %r15d
	movl	$0, %eax
	subl	$1, %r15d
	cmovs	%eax, %r15d
	cmpl	$-1, %ebx
	je	.L962
	testl	%ebx, %ebx
	jle	.L710
.L978:
	testl	%r15d, %r15d
	jle	.L710
	movslq	%r15d, %rax
	movq	%rdi, %rdx
	xorl	%ecx, %ecx
	salq	$4, %rax
	subq	%rax, %rdx
	xorl	%eax, %eax
	jmp	.L682
	.p2align 4,,10
.L963:
	cmpl	%eax, %r15d
	jle	.L681
.L682:
	movq	(%rdx,%rcx), %r9
	addl	$1, %eax
	movq	8(%rdx,%rcx), %r10
	movq	%r9, (%rsi,%rcx)
	movq	%r10, 8(%rsi,%rcx)
	addq	$16, %rcx
	cmpl	%eax, %ebx
	jg	.L963
.L681:
	cmpl	%eax, %ebx
	jle	.L357
	subl	$1, %ebx
	movslq	%eax, %rcx
	subl	%eax, %ebx
	movq	%rcx, %rdx
	addq	%rcx, %rbx
	salq	$4, %rdx
	leaq	8(%rsi,%rdx), %rdx
	salq	$4, %rbx
	leaq	24(%rsi,%rbx), %rax
	.p2align 4,,10
.L685:
	movl	$0, (%rdx)
	addq	$16, %rdx
	cmpq	%rax, %rdx
	jne	.L685
	jmp	.L357
	.p2align 4,,10
.L371:
	movl	%ebx, %r15d
	movq	%r14, %rcx
	shrl	$14, %ebx
	call	luaH_new
	andl	$511, %ebx
	shrl	$23, %r15d
	movl	$69, 8(%rsi)
	movq	%rax, %rdx
	movq	%rax, (%rsi)
	movl	%ebx, %eax
	orl	%r15d, %eax
	jne	.L964
.L677:
	movq	24(%r14), %rax
	cmpq	$0, 24(%rax)
	jle	.L357
	addq	$16, %rsi
	movq	%r14, %rcx
	movq	%rsi, 16(%r14)
	call	luaC_step
	movq	8(%rbp), %rax
	movq	%rax, 16(%r14)
	movq	32(%rbp), %rdi
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L384:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L519
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L520:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L521
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L522:
	cmpl	$19, 8(%r15)
	jne	.L523
	movq	(%r15), %rax
	movq	%rax, 128(%rsp)
.L524:
	cmpl	$19, 8(%rbx)
	jne	.L526
	movq	(%rbx), %rcx
.L527:
	negq	%rcx
.L922:
	testq	%rcx, %rcx
	movq	128(%rsp), %rdx
	js	.L965
.L528:
	salq	%cl, %rdx
	movl	$0, %eax
	cmpq	$63, %rcx
	cmovle	%rdx, %rax
	jmp	.L910
	.p2align 4,,10
.L364:
	shrl	$23, %ebx
	.p2align 4,,10
.L408:
	subl	$1, %ebx
	addq	$16, %rsi
	movl	$0, -8(%rsi)
	cmpl	$-1, %ebx
	jne	.L408
	jmp	.L357
	.p2align 4,,10
.L385:
	shrl	$23, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	movl	8(%rbx), %eax
	cmpl	$19, %eax
	je	.L966
	cmpl	$3, %eax
	jne	.L567
	movsd	(%rbx), %xmm0
.L568:
	xorpd	%xmm8, %xmm0
	jmp	.L909
	.p2align 4,,10
.L383:
	movl	%ebx, %eax
	shrl	$23, %eax
	testb	$1, %ah
	je	.L507
	movzbl	%al, %eax
	salq	$4, %rax
	leaq	(%r12,%rax), %r15
.L508:
	shrl	$14, %ebx
	testb	$1, %bh
	je	.L509
	movzbl	%bl, %ebx
	salq	$4, %rbx
	addq	%r12, %rbx
.L510:
	cmpl	$19, 8(%r15)
	jne	.L511
	movq	(%r15), %rax
	movq	%rax, 128(%rsp)
.L512:
	cmpl	$19, 8(%rbx)
	jne	.L514
	movq	(%rbx), %rcx
	movq	128(%rsp), %rdx
	testq	%rcx, %rcx
	jns	.L528
.L965:
	xorl	%eax, %eax
	cmpq	$-63, %rcx
	jl	.L910
	negl	%ecx
	movq	%rdx, %rax
	shrq	%cl, %rax
	jmp	.L910
	.p2align 4,,10
.L365:
	movq	56(%rsp), %rax
	shrl	$23, %ebx
	movslq	%ebx, %rbx
	movq	32(%rax,%rbx,8), %rax
	movq	(%rax), %rax
.L900:
	movq	8(%rax), %rdx
	movq	(%rax), %rax
	movq	%rdx, 8(%rsi)
	movq	%rax, (%rsi)
	movq	40(%rbp), %rax
	jmp	.L356
	.p2align 4,,10
.L363:
	movl	%ebx, %eax
	movl	$1, 8(%rsi)
	shrl	$23, %eax
	andl	$8372224, %ebx
	movl	%eax, (%rsi)
	je	.L357
.L825:
	movq	40(%rbp), %rax
	addq	$4, %rax
	movq	%rax, 40(%rbp)
	jmp	.L356
	.p2align 4,,10
.L932:
	movq	%r14, %rcx
	call	luaG_traceexec
	movq	32(%rbp), %rdi
	jmp	.L358
	.p2align 4,,10
.L958:
	movq	%r15, %rdx
	movq	%r14, %rcx
	call	luaC_barrierback_
	jmp	.L665
	.p2align 4,,10
.L570:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L967
	movl	$19, 32(%rsp)
.L907:
	movq	%rsi, %r9
	movq	%rbx, %r8
	movq	%rbx, %rdx
	movq	%r14, %rcx
	call	luaT_trybinTM
	movq	32(%rbp), %rdi
	jmp	.L357
	.p2align 4,,10
.L481:
	leaq	128(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%r15, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L482
.L483:
	movl	$13, 32(%rsp)
	.p2align 4,,10
.L908:
	movq	%rsi, %r9
	movq	%rbx, %r8
	movq	%r15, %rdx
	movq	%r14, %rcx
	call	luaT_trybinTM
	movq	32(%rbp), %rdi
	jmp	.L357
	.p2align 4,,10
.L501:
	leaq	128(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%r15, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L502
.L503:
	movl	$15, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L523:
	leaq	128(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%r15, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L524
.L525:
	movl	$17, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L511:
	leaq	128(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%r15, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L512
.L513:
	movl	$16, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L471:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L472
.L473:
	movl	$11, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L491:
	leaq	128(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%r15, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	jne	.L492
.L493:
	movl	$14, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L559:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L560
.L561:
	movl	$10, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L655:
	movq	80(%rsp), %rdx
	movq	%rsi, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L968
	movsd	120(%rsp), %xmm0
	movsd	136(%rsp), %xmm1
	jmp	.L656
	.p2align 4,,10
.L652:
	movq	64(%rsp), %rdx
	leaq	32(%rsi), %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L969
	movsd	136(%rsp), %xmm1
	jmp	.L653
	.p2align 4,,10
.L649:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L970
	movsd	128(%rsp), %xmm0
	jmp	.L650
	.p2align 4,,10
.L436:
	movl	8(%r15), %eax
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, %eax
	jne	.L438
.L961:
	cmpl	$19, 8(%rbx)
	je	.L971
.L439:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L441
.L442:
	movl	$6, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L434:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L435
	.p2align 4,,10
.L595:
	movslq	%ebx, %rbx
	salq	$4, %rbx
	leaq	(%rdi,%rbx), %rdx
	jmp	.L596
	.p2align 4,,10
.L593:
	andl	$511, %eax
	salq	$4, %rax
	leaq	(%rdi,%rax), %r8
	jmp	.L594
	.p2align 4,,10
.L458:
	movl	8(%r15), %eax
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, %eax
	jne	.L460
.L952:
	cmpl	$19, 8(%rbx)
	je	.L972
.L461:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L463
.L464:
	movl	$8, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L456:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L457
	.p2align 4,,10
.L546:
	movl	8(%r15), %eax
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, %eax
	jne	.L548
.L959:
	cmpl	$19, 8(%rbx)
	je	.L973
.L549:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L551
.L552:
	movl	$12, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L544:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L545
	.p2align 4,,10
.L469:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L470
	.p2align 4,,10
.L467:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L468
	.p2align 4,,10
.L557:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L558
	.p2align 4,,10
.L555:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L556
	.p2align 4,,10
.L447:
	movl	8(%r15), %eax
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, %eax
	jne	.L449
.L960:
	cmpl	$19, 8(%rbx)
	je	.L974
.L450:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L452
.L453:
	movl	$7, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L445:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L446
	.p2align 4,,10
.L600:
	testl	%eax, %eax
	je	.L918
	cmpl	$1, %eax
	jne	.L825
	movl	(%rsi), %r10d
	testl	%r10d, %r10d
	setne	%al
.L602:
	testb	%al, %al
	je	.L918
	jmp	.L825
	.p2align 4,,10
.L431:
	andl	$511, %ebx
	salq	$4, %rbx
	leaq	(%rdi,%rbx), %r8
	jmp	.L432
	.p2align 4,,10
.L489:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L490
	.p2align 4,,10
.L487:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L488
	.p2align 4,,10
.L479:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L480
	.p2align 4,,10
.L477:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L478
	.p2align 4,,10
.L533:
	movl	8(%r15), %eax
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	cmpl	$19, %eax
	jne	.L535
.L950:
	cmpl	$19, 8(%rbx)
	je	.L975
.L536:
	leaq	128(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L538
.L539:
	movl	$9, 32(%rsp)
	jmp	.L908
	.p2align 4,,10
.L531:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L532
	.p2align 4,,10
.L509:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L510
	.p2align 4,,10
.L507:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L508
	.p2align 4,,10
.L521:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L522
	.p2align 4,,10
.L519:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L520
	.p2align 4,,10
.L499:
	andl	$511, %ebx
	salq	$4, %rbx
	addq	%rdi, %rbx
	jmp	.L500
	.p2align 4,,10
.L497:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %r15
	jmp	.L498
	.p2align 4,,10
.L588:
	movslq	%ebx, %rbx
	salq	$4, %rbx
	leaq	(%rdi,%rbx), %rdx
	jmp	.L589
	.p2align 4,,10
.L586:
	andl	$511, %eax
	salq	$4, %rax
	leaq	(%rdi,%rax), %r8
	jmp	.L587
	.p2align 4,,10
.L581:
	andl	$511, %ebx
	salq	$4, %rbx
	leaq	(%rdi,%rbx), %r8
	jmp	.L582
	.p2align 4,,10
.L579:
	cltq
	salq	$4, %rax
	leaq	(%rdi,%rax), %rdx
	jmp	.L580
	.p2align 4,,10
.L606:
	testl	%edx, %edx
	je	.L610
	cmpl	$1, %edx
	jne	.L825
	movl	(%rax), %r8d
	testl	%r8d, %r8d
	setne	%dl
.L608:
	testb	%dl, %dl
	je	.L610
	jmp	.L825
.L669:
	movq	%r10, (%rsi)
	movl	$70, 8(%rsi)
	jmp	.L677
.L504:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L503
	movq	136(%rsp), %rax
	jmp	.L505
.L562:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L561
	movsd	136(%rsp), %xmm1
	jmp	.L563
.L474:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L473
	movsd	136(%rsp), %xmm1
	jmp	.L475
.L494:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L493
	movq	136(%rsp), %rax
	jmp	.L495
.L484:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L483
	movq	136(%rsp), %rax
	jmp	.L485
.L526:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L525
	movq	136(%rsp), %rcx
	jmp	.L527
.L514:
	movq	64(%rsp), %rdx
	xorl	%r8d, %r8d
	movq	%rbx, %rcx
	call	luaV_tointeger
	testl	%eax, %eax
	je	.L513
	movq	136(%rsp), %rcx
	jmp	.L922
.L567:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	jne	.L976
	movl	$18, 32(%rsp)
	jmp	.L907
.L540:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L539
	movsd	136(%rsp), %xmm1
	jmp	.L541
.L553:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L552
	movsd	136(%rsp), %xmm1
	jmp	.L554
.L465:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L464
	movsd	136(%rsp), %xmm0
	jmp	.L466
.L443:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L442
	movsd	136(%rsp), %xmm0
	jmp	.L444
.L454:
	movq	64(%rsp), %rdx
	movq	%rbx, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L453
	movsd	136(%rsp), %xmm1
	jmp	.L455
.L964:
	movl	%ebx, %ecx
	movq	%rdx, 72(%rsp)
	call	luaO_fb2int
	movl	%r15d, %ecx
	movl	%eax, %ebx
	call	luaO_fb2int
	movq	72(%rsp), %rdx
	movl	%ebx, %r9d
	movq	%r14, %rcx
	movl	%eax, %r8d
	call	luaH_resize
	jmp	.L677
.L957:
	movl	%eax, %r8d
	movq	%r15, %rdx
	movq	%r14, %rcx
	movl	%r9d, 88(%rsp)
	movl	%eax, 72(%rsp)
	call	luaH_resizearray
	movl	88(%rsp), %r9d
	movl	72(%rsp), %eax
	jmp	.L663
.L940:
	movq	32(%rbp), %rax
	movq	%r14, %rcx
	leaq	-16(%rax,%r9), %rdx
	call	luaF_close
	jmp	.L578
.L935:
	movq	32(%rbp), %rdx
	salq	$4, %rax
	movq	%r14, %rcx
	leaq	-16(%rdx,%rax), %rdx
	call	luaF_close
	movq	40(%rbp), %rdx
	jmp	.L611
.L966:
	movq	(%rbx), %rax
	movl	$19, 8(%rsi)
	negq	%rax
	movq	%rax, (%rsi)
	jmp	.L357
.L975:
	movq	(%rbx), %r8
	movq	%r14, %rcx
	movq	(%r15), %rdx
	call	luaV_mod
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
.L973:
	movq	(%rbx), %r8
	movq	%r14, %rcx
	movq	(%r15), %rdx
	call	luaV_div
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
.L974:
	movq	(%r15), %rax
	subq	(%rbx), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
.L972:
	movq	(%rbx), %rax
	imulq	(%r15), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
.L971:
	movq	(%r15), %rax
	addq	(%rbx), %rax
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L357
.L941:
	cmpl	$19, 40(%rsi)
	jne	.L637
	movq	32(%rsi), %rax
	leaq	112(%rsp), %rdx
	movq	%r15, %rcx
	movq	%rax, 72(%rsp)
	sarq	$63, %rax
	notl	%eax
	leal	2(%rax), %r8d
	call	luaV_tointeger
	movq	112(%rsp), %rdx
	testl	%eax, %eax
	jne	.L640
	cmpl	$3, 24(%rsi)
	jne	.L641
	movsd	16(%rsi), %xmm0
	movsd	%xmm0, 136(%rsp)
	ucomisd	%xmm9, %xmm0
	jbe	.L895
.L979:
	movabsq	$9223372036854775807, %rax
	movabsq	$9223372036854775807, %rdx
	movq	%rax, 112(%rsp)
	movq	72(%rsp), %rax
	shrq	$63, %rax
	movq	%rax, %r15
.L646:
	xorl	%eax, %eax
	testl	%r15d, %r15d
	jne	.L647
.L640:
	movq	(%rsi), %rax
.L647:
	subq	32(%rsi), %rax
	movq	%rdx, 16(%rsi)
	movl	$19, 24(%rsi)
	movl	$19, 8(%rsi)
	movq	%rax, (%rsi)
	jmp	.L648
.L946:
	movq	32(%rsi), %rax
	movq	16(%rsi), %rcx
	movq	%rax, %rdx
	addq	(%rsi), %rdx
	testq	%rax, %rax
	jle	.L630
	cmpq	%rcx, %rdx
	setle	%al
.L631:
	testb	%al, %al
	je	.L357
	movq	40(%rbp), %rcx
	shrl	$14, %ebx
	movl	%ebx, %eax
	leaq	-524284(%rcx,%rax,4), %rax
	movq	%rax, 40(%rbp)
	movq	%rdx, (%rsi)
	movq	%rdx, 48(%rsi)
	movl	$19, 56(%rsi)
	jmp	.L356
.L962:
	movq	48(%r14), %rax
	movslq	%r15d, %rbx
	subq	16(%r14), %rax
	sarq	$4, %rax
	cmpq	%rbx, %rax
	jle	.L977
.L680:
	movq	32(%rbp), %rdi
	salq	$4, %rbx
	leaq	(%rdi,%r9), %rsi
	leaq	(%rsi,%rbx), %rax
	movl	%r15d, %ebx
	testl	%ebx, %ebx
	movq	%rax, 16(%r14)
	jg	.L978
.L710:
	xorl	%eax, %eax
	jmp	.L681
.L936:
	movq	32(%rbp), %rdx
	salq	$4, %rax
	movq	%r14, %rcx
	leaq	-16(%rdx,%rax), %rdx
	call	luaF_close
	movq	40(%rbp), %rdx
	jmp	.L599
.L967:
	movq	136(%rsp), %rax
	jmp	.L571
.L894:
	ucomisd	%xmm2, %xmm1
	setae	%al
	jmp	.L635
.L976:
	movsd	136(%rsp), %xmm0
	jmp	.L568
.L951:
	addsd	%xmm1, %xmm0
	jmp	.L909
.L944:
	movl	(%rax), %ebx
	xorl	%edx, %edx
	testl	%ebx, %ebx
	sete	%dl
	jmp	.L574
.L933:
	movq	%r14, %rcx
	call	lua_checksig_.part.3
	jmp	.L658
.L668:
	movl	4(%rax), %ebx
	movq	%r14, %rcx
	movq	%r8, 88(%rsp)
	movq	72(%rax), %r15
	movq	%r9, 72(%rsp)
	movl	%ebx, %edx
	call	luaF_newLclosure
	movq	72(%rsp), %r9
	addq	$9, %r15
	testl	%ebx, %ebx
	movq	%rax, %r10
	movq	88(%rsp), %r8
	movq	%r9, 24(%rax)
	movq	%rax, (%rsi)
	movl	$70, 8(%rsi)
	jg	.L686
.L687:
	testb	$4, 9(%r9)
	jne	.L677
	movq	%r10, 40(%r9)
	jmp	.L677
.L977:
	movl	%r15d, %edx
	movq	%r14, %rcx
	movq	%r9, 72(%rsp)
	call	luaD_growstack
	movq	72(%rsp), %r9
	jmp	.L680
.L630:
	cmpq	%rdx, %rcx
	setle	%al
	jmp	.L631
.L943:
	movl	(%rax), %r9d
	testl	%r9d, %r9d
	sete	%dl
	jmp	.L608
.L934:
	movl	(%rsi), %r11d
	testl	%r11d, %r11d
	sete	%al
	jmp	.L602
.L956:
	movq	72(%rsp), %rsi
	movq	%rbx, %r10
	movq	88(%rsp), %r12
	movq	96(%rsp), %r9
	movq	104(%rsp), %rbp
	jmp	.L687
.L937:
	movq	%r14, %rcx
	call	lua_checksig_.part.3
	jmp	.L617
.L942:
	movq	%r14, %rcx
	call	lua_checksig_.part.3
	jmp	.L612
.L945:
	movq	%r14, %rcx
	call	lua_checksig_.part.3
	jmp	.L628
.L939:
	movq	%r14, %rcx
	movq	%r9, 72(%rsp)
	call	lua_checksig_.part.3
	movq	72(%rsp), %r9
	jmp	.L577
.L354:
	movaps	144(%rsp), %xmm6
	movaps	160(%rsp), %xmm7
	movaps	176(%rsp), %xmm8
	movaps	192(%rsp), %xmm9
	addq	$216, %rsp
	popq	%rbx
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	ret
.L938:
	movq	32(%r14), %r12
	movq	(%r12), %rsi
	movq	32(%r12), %rdx
	movq	16(%r12), %rbp
	movq	(%rsi), %rax
	movq	0(%rbp), %rbx
	movq	24(%rax), %rax
	movq	16(%rax), %rax
	movzbl	(%rax), %edi
	movq	56(%rsp), %rax
	salq	$4, %rdi
	movq	24(%rax), %rax
	addq	%rdx, %rdi
	movq	16(%rax), %rax
	movl	20(%rax), %ecx
	testl	%ecx, %ecx
	jle	.L620
	movq	32(%rbp), %rdx
	movq	%r14, %rcx
	call	luaF_close
	movq	32(%r12), %rdx
.L620:
	cmpq	%rdi, %rsi
	jae	.L623
	movq	%rsi, %rax
	notq	%rax
	addq	%rdi, %rax
	andq	$-16, %rax
	leaq	16(%rax), %rcx
	xorl	%eax, %eax
.L622:
	movq	(%rsi,%rax), %r9
	movq	8(%rsi,%rax), %r10
	movq	%r9, (%rbx,%rax)
	movq	%r10, 8(%rbx,%rax)
	addq	$16, %rax
	cmpq	%rcx, %rax
	jne	.L622
.L623:
	movq	%rdx, %rax
	subq	%rsi, %rax
	addq	%rbx, %rax
	movq	%rax, 32(%rbp)
	movq	%rbx, %rax
	subq	%rsi, %rax
	addq	16(%r14), %rax
	movq	%rax, 16(%r14)
	movq	%rax, 8(%rbp)
	movq	40(%r12), %rax
	orw	$32, 66(%rbp)
	movq	%rax, 40(%rbp)
	movq	%rbp, 32(%r14)
	jmp	.L355
.L614:
	movq	32(%r14), %rbp
	jmp	.L355
.L641:
	movq	64(%rsp), %rdx
	movq	%r15, %rcx
	call	luaV_tonumber_
	testl	%eax, %eax
	je	.L637
	movsd	136(%rsp), %xmm0
	ucomisd	%xmm9, %xmm0
	ja	.L979
.L895:
	movabsq	$-9223372036854775808, %rax
	movq	72(%rsp), %r15
	movq	%rax, 112(%rsp)
	movq	%rax, %rdx
	notq	%r15
	shrq	$63, %r15
	jmp	.L646
.L949:
	movq	%r14, %rcx
	movq	%r9, 72(%rsp)
	call	luaC_barrierback_
	movq	72(%rsp), %r9
	jmp	.L428
.L969:
	leaq	.LC30(%rip), %rdx
	movq	%r14, %rcx
	call	luaG_runerror
.L970:
	leaq	.LC29(%rip), %rdx
	movq	%r14, %rcx
	call	luaG_runerror
.L968:
	leaq	.LC31(%rip), %rdx
	movq	%r14, %rcx
	call	luaG_runerror
	nop
	.seh_endproc
	.section	.text.unlikely,"x"
.LCOLDE32:
	.text
.LHOTE32:
	.globl	skynet_sig_L
	.bss
	.align 8
skynet_sig_L:
	.space 8
	.section .rdata,"dr"
	.align 8
.LC5:
	.long	0
	.long	1072693248
	.align 8
.LC6:
	.long	0
	.long	-1008730112
	.align 8
.LC7:
	.long	0
	.long	1138753536
	.align 16
.LC28:
	.long	0
	.long	-2147483648
	.long	0
	.long	0
	.ident	"GCC: (x86_64-posix-seh-rev1, Built by MinGW-W64 project) 4.9.2"
	.def	strlen;	.scl	2;	.type	32;	.endef
	.def	strcoll;	.scl	2;	.type	32;	.endef
	.def	memcpy;	.scl	2;	.type	32;	.endef
	.def	lua_pushnil;	.scl	2;	.type	32;	.endef
	.def	lua_error;	.scl	2;	.type	32;	.endef
	.def	luaO_str2num;	.scl	2;	.type	32;	.endef
	.def	floor;	.scl	2;	.type	32;	.endef
	.def	luaT_gettm;	.scl	2;	.type	32;	.endef
	.def	luaT_gettmbyobj;	.scl	2;	.type	32;	.endef
	.def	luaG_typeerror;	.scl	2;	.type	32;	.endef
	.def	luaH_get;	.scl	2;	.type	32;	.endef
	.def	luaT_callTM;	.scl	2;	.type	32;	.endef
	.def	luaG_runerror;	.scl	2;	.type	32;	.endef
	.def	luaC_barrierback_;	.scl	2;	.type	32;	.endef
	.def	luaH_newkey;	.scl	2;	.type	32;	.endef
	.def	luaT_callorderTM;	.scl	2;	.type	32;	.endef
	.def	luaG_ordererror;	.scl	2;	.type	32;	.endef
	.def	luaS_eqlngstr;	.scl	2;	.type	32;	.endef
	.def	luaT_trybinTM;	.scl	2;	.type	32;	.endef
	.def	luaO_tostring;	.scl	2;	.type	32;	.endef
	.def	luaS_newlstr;	.scl	2;	.type	32;	.endef
	.def	luaS_createlngstrobj;	.scl	2;	.type	32;	.endef
	.def	luaH_getn;	.scl	2;	.type	32;	.endef
	.def	luaD_call;	.scl	2;	.type	32;	.endef
	.def	luaF_close;	.scl	2;	.type	32;	.endef
	.def	luaD_poscall;	.scl	2;	.type	32;	.endef
	.def	luaD_precall;	.scl	2;	.type	32;	.endef
	.def	luaC_step;	.scl	2;	.type	32;	.endef
	.def	luaC_upvalbarrier_;	.scl	2;	.type	32;	.endef
	.def	pow;	.scl	2;	.type	32;	.endef
	.def	fmod;	.scl	2;	.type	32;	.endef
	.def	luaF_newLclosure;	.scl	2;	.type	32;	.endef
	.def	luaF_findupval;	.scl	2;	.type	32;	.endef
	.def	luaH_setint;	.scl	2;	.type	32;	.endef
	.def	luaH_getstr;	.scl	2;	.type	32;	.endef
	.def	luaH_new;	.scl	2;	.type	32;	.endef
	.def	luaG_traceexec;	.scl	2;	.type	32;	.endef
	.def	luaO_fb2int;	.scl	2;	.type	32;	.endef
	.def	luaH_resize;	.scl	2;	.type	32;	.endef
	.def	luaH_resizearray;	.scl	2;	.type	32;	.endef
	.def	luaD_growstack;	.scl	2;	.type	32;	.endef
	.section	.rdata$.refptr.luaO_nilobject_, "dr"
	.globl	.refptr.luaO_nilobject_
	.linkonce	discard
.refptr.luaO_nilobject_:
	.quad	luaO_nilobject_
