/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>

# Shift Right Logical 
#define SRL(val, shamt)		(((val) >> (shamt)) & ~(-1 << (32 - (shamt))))


###################################################################
# The kernel (this code) is linked at address ~(KERNBASE + 1 Meg), 
# but the bootloader loads it at address ~1 Meg.
#	
# RELOC(x) maps a symbol x from its link address to its actual
# location in physical memory (its load address).	 
###################################################################

#define	RELOC(x) ((x) - KERNBASE)

#define MULTIBOOT_HEADER_MAGIC (0x1BADB002)
#define MULTIBOOT_HEADER_FLAGS (0)
#define CHECKSUM (-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS))

###################################################################
# entry point
###################################################################
.set CODE_SEL,0x8
.set DATA_SEL,0x10

.text

# The Multiboot header
.align 4
.long MULTIBOOT_HEADER_MAGIC
.long MULTIBOOT_HEADER_FLAGS
.long CHECKSUM

# '_start' specifies the ELF entry point.  Since we haven't set up
# virtual memory when the bootloader enters this code, we need the
# bootloader to jump to the *physical* address of the entry point.
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot

    # In head64.S we had set the initial 1G boot_page tables
    # But both the descriptor table and the page tables are
    # located in the low memory that is in the first 640k region
    # We would want to recreate them so that that they are at a higher
    # address that is above KERNBASE(in terms of virtual addresses, or above 1M in terms of physical addresses),
    # so that that low memory is free to use later.
    # So, Here we set the global descriptor tables. In pmap.c we will set
    # page tables as a part of lab2.
    
    movabs   $gdtdesc_64,%rax
    lgdt     (%rax)
    movw    $DATA_SEL,%ax
    movw    %ax,%ds
    movw    %ax,%ss
    movw    %ax,%fs
    movw    %ax,%gs
    movw    %ax,%es
    pushq   $CODE_SEL
    movabs  $relocated,%rax
    pushq   %rax
    lretq

relocated:

	# Clear the frame pointer register (RBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movq	$0x0,%rbp			# nuke frame pointer

	# Set the stack pointer
	movabs	$(bootstacktop),%rax
    movq  %rax,%rsp

	# now to C code
	call	i386_init

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin


.data
###################################################################
# boot stack
###################################################################
	.p2align	PGSHIFT		# force page alignment
	.globl		bootstack
bootstack:
	.space		KSTKSIZE
	.globl		bootstacktop   
bootstacktop:

.data
    
    .p2align 3
    .globl kernel_64
kernel_64:
    SEG_NULL
    SEG64(STA_X|STA_R,0x0,0xffffffff)    #64 bit CS
    SEG64(STA_R|STA_W,0x0,0xffffffff)    #64 bit DS
    SEG64USER(STA_X|STA_R,0x0,0xffffffff) #64 bit USER CS
    SEG64USER(STA_R|STA_W,0x0,0xffffffff) # USER data
    .quad   0x0080890000000000  /* TS descriptor */ 
    .quad   0x0000000000000000 /* TS continued */

     .globl gdtdesc_64
gdtdesc_64:
    .word 0x37 
    .long kernel_64

