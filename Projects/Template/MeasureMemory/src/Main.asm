INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT    EQU 0FFFh
MEASURE_ERROR_THRESHOLD EQU 1000

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0 DB "|-------------------|", 0Ah, 0
format1 DB "|                   |", 0Ah, 0
format2 DB "|   Measure Memory  |", 0Ah, 0
format3 DB "|                   |", 0Ah, 0
format4 DB "|-------------------|", 0Ah, 0
format5 DB "|   Min   |   Avg   |", 0Ah, 0
format6 DB "|---------|---------|", 0Ah, 0
format7 DB "| %  7llu | %  7.2f |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ?
        measureAvg            QWORD ?
        measureRetryCountdown DWORD ?
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

    mov @Param(3, DWORD), 404h  ; PAGE_READWRITE | PAGE_WRITECOMBINE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    mov stack.measureMin, -1
    mov stack.measureAvg, 0
    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

    ALIGN 16
@@:
    rdtscp
    lfence
    mov esi, eax
    mov edi, edx

    mov eax, [rbp]

    rdtscp
    lfence
    shl rdi, 32
    shl rdx, 32
    or rdi, rsi
    or rdx, rax
    sub rdx, rdi

    cmp rdx, MEASURE_ERROR_THRESHOLD
    ja @B

    cmp rdx, stack.measureMin
    cmova rdx, stack.measureMin
    mov stack.measureMin, rdx

    add stack.measureAvg, rdx

    sub stack.measureRetryCountdown, 1
    jae @B

    mov rax, stack.measureAvg
    mov rdx, MEASURE_RETRY_AMOUNT
    cvtsi2sd xmm0, rax
    cvtsi2sd xmm1, rdx
    divsd xmm0, xmm1
    movq stack.measureAvg, xmm0

    @Call printf, OFFSET format7, stack.measureMin, stack.measureAvg

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

END
