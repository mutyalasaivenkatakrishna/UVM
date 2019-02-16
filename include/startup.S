.option norvc
.section .text.start
.global _start

_start:

    # Initialize stack pointer
#    li sp, 0x80010000
    la sp, _stack_top

    # Call C main()
    call main

## If main returns, loop forever
#hang:
#    j hang


