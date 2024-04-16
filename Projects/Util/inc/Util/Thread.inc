IFNDEF UTIL_THREAD_INC
UTIL_THREAD_INC EQU -1

CreateSimpleThread PROTO

@Sync MACRO Dst:REQ, Src:REQ, Op:=<jne>
    LOCAL Loop

    ALIGN 16
Loop:
    cmp Dst, Src
    Op Loop
ENDM

ENDIF
