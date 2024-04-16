INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT           EQU 16
ROW_OFFSET           EQU 0
ROW_SIZE             EQU 3
MEASURE_RETRY_AMOUNT EQU 0FFFh
DELAY_PAUSE_AMOUNT   EQU 512

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0 DB "|----------------------|", 0Ah, 0
format1 DB "|                      |", 0Ah, 0
format2 DB "|   Speculative Fetch  |", 0Ah, 0
format3 DB "|                      |", 0Ah, 0
format4 DB "|----------------------|", 0Ah, 0
format5 DB "| Cache Line |  Effect |", 0Ah, 0
format6 DB "|------------|---------|", 0Ah, 0
format7 DB "| %    10llu | %  7llu |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ?
        measureRetryCountdown DWORD ?
        rowCount              DWORD ?
    Stack_main ENDS

    MaxParam_main = 4
    @ProcBegin 8 * MaxParam_main + SIZE(Stack_main), rsi, rdi, rbp, r12

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

    Bytes = CACHE_LINE_SIZE * (ROW_AMOUNT * ROW_SIZE + ROW_OFFSET)

    mov @Param(3, DWORD), 40h   ; PAGE_EXECUTE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), Bytes
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    mov stack.measureMin, -1
    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT
    mov stack.rowCount, 0

    mov ecx, (Bytes / 4) - 1

    ALIGN 16
@@:
    mov DWORD PTR [rbp + rcx * 4], 0401F0Fh ; nop

    sub ecx, 1
    jae @B

    mov r12, CACHE_LINE_SIZE * ROW_OFFSET

    ALIGN 16
@@:
    mov DWORD PTR [rbp],             0401F0Fh ; nop
    mov DWORD PTR [rbp + Bytes - 4], 01F66C3h ; ret

    call rbp

    mov DWORD PTR [rbp], 0001F66C3h ; ret
    
    clflush [rbp + r12]
    mfence
    call rbp

    xor eax, eax
    cpuid

    rdtscp
    lfence
    mov esi, eax
    mov edi, edx

    mov eax, [rbp + r12]

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

    call Delay

    sub stack.measureRetryCountdown, 1
    jae @B

    mov eax, ROW_SIZE
    mul stack.rowCount
    add eax, ROW_OFFSET
    @Call printf, OFFSET format7, eax, stack.measureMin

    mov stack.measureMin, -1
    mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

    add r12, CACHE_LINE_SIZE * ROW_SIZE
    add stack.rowCount, 1
    cmp stack.rowCount, ROW_AMOUNT
    jb @B

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), CACHE_LINE_SIZE * ROW_AMOUNT
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

Delay PROC
    REPEAT DELAY_PAUSE_AMOUNT
        pause
    ENDM

    ret
Delay ENDP

END
