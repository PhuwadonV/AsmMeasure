INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT           EQU 16
MEASURE_RETRY_AMOUNT EQU 0FFFh

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
format2 DB "| Mem Commit Access |", 0Ah, 0
format3 DB "|                   |", 0Ah, 0
format4 DB "|-------------------|", 0Ah, 0
format5 DB "|  Access |  Cycle  |", 0Ah, 0
format6 DB "|---------|---------|", 0Ah, 0
format7 DB "| %  7llu | %  7llu |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ROW_AMOUNT DUP(?)
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

    mov rax, -1
    mov ecx, ROW_AMOUNT - 1

    ALIGN 16
@@:
    mov stack.measureMin[rcx * 8], rax

    sub ecx, 1
    jae @B

    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

    ALIGN 16
@@:
    mov stack.rowCount, 0

    mov @Param(3, DWORD), 4h    ; PAGE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    ALIGN 16
Access:
    xor eax, eax
    cpuid

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

    mov eax, stack.rowCount
    cmp rdx, stack.measureMin[rax * 8]
    cmova rdx, stack.measureMin[rax * 8]
    mov stack.measureMin[rax * 8], rdx

    add stack.rowCount, 1
    cmp stack.rowCount, ROW_AMOUNT
    jb Access

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    sub stack.measureRetryCountdown, 1
    jae @B

    xor ebp, ebp

    ALIGN 16
@@:
    mov @Param(2, QWORD), stack.measureMin[rbp * 8]
    mov @Param(1, DWORD), ebp
    inc @Param(1, DWORD)
    @Call printf, OFFSET format7

    add ebp, 1
    cmp ebp, ROW_AMOUNT
    jb @B

    xor eax, eax
    @ProcEnd
main ENDP

END
