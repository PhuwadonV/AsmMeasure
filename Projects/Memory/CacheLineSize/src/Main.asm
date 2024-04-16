INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT           EQU 16
ROW_OFFSET           EQU 0
MEASURE_RETRY_AMOUNT EQU 0FFFh

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR

.CONST
format0 DB "|-------------------|", 0Ah, 0
format1 DB "|                   |", 0Ah, 0
format2 DB "|  Cache Line Size  |", 0Ah, 0
format3 DB "|                   |", 0Ah, 0
format4 DB "|-------------------|", 0Ah, 0
format5 DB "|  Bytes  |  Effect |", 0Ah, 0
format6 DB "|---------|---------|", 0Ah, 0
format7 DB "| %  7llu | %  7llu |", 0Ah, 0

.DATA
memory DQ (ROW_AMOUNT + ROW_OFFSET) DUP(?)

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ?
        measureRetryCountdown DWORD ?
        rowCount              DWORD ?
    Stack_main ENDS

    MaxParam_main = 4
    @ProcBegin 8 * MaxParam_main + SIZE(Stack_main), rsi, rdi, rbp

    @Var Stack_main, stack, [rsp + 8 * MaxParam_main]

    call __imp_GetCurrentThread
    mov @Param(1, DWORD), 1
    mov @Param(0, QWORD), rax
    call __imp_SetThreadAffinityMask

    call __imp_GetCurrentProcess
    mov @Param(1, DWORD), 100h
    mov @Param(0, QWORD), rax
    call __imp_SetPriorityClass

    call __imp_GetCurrentThread
    mov @Param(1, DWORD), 15
    mov @Param(0, QWORD), rax
    call __imp_SetThreadPriority

    @Call printf, OFFSET format0
    @Call printf, OFFSET format1
    @Call printf, OFFSET format2
    @Call printf, OFFSET format3
    @Call printf, OFFSET format4
    @Call printf, OFFSET format5
    @Call printf, OFFSET format6

    mov stack.measureMin, -1
    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT
    mov stack.rowCount, 0

    mov rbp, (OFFSET memory) + ROW_OFFSET * 8

    ALIGN 16
@@:
    I = 0

    REPEAT ROW_AMOUNT + ROW_OFFSET
        mov rax, [memory + 8 * I]

        I = I + 1
    ENDM

    clflush memory

    xor eax, eax
    cpuid

    rdtscp
    lfence
    mov esi, eax
    mov edi, edx

    mov rax, [rbp]

    rdtscp
    lfence
    shl rdi, 32
    shl rdx, 32
    or rdi, rsi
    or rdx, rax
    sub rdx, rdi

    cmp rdx, stack.measureMin
    cmova rdx, stack.measureMin
    mov stack.measureMin, rdx

    sub stack.measureRetryCountdown, 1
    jae @B

    mov @Param(2, QWORD), stack.measureMin
    mov @Param(1, DWORD), stack.rowCount
    add @Param(1, DWORD), ROW_OFFSET
    shl @Param(1, DWORD), 3
    @Call printf, OFFSET format7

    mov stack.measureMin, -1
    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

    add rbp, 8
    add stack.rowCount, 1
    cmp stack.rowCount, ROW_AMOUNT
    jb @B

    xor eax, eax
    @ProcEnd
main ENDP

END
