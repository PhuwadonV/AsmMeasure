INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT    EQU 0FFFh
MEASURE_ERROR_THRESHOLD EQU 1000
CACHE_L1D_SIZE          EQU 0C000h

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0  DB "|-------------------------------|", 0Ah, 0
format1  DB "|                               |", 0Ah, 0
format2  DB "| Cache Pollution From Prefetch |", 0Ah, 0
format3  DB "|                               |", 0Ah, 0
format4  DB "|-------------------------------|", 0Ah, 0
format5  DB "| Assume Cache Size = %----9llu |", 0Ah, 0
format6  DB "|-------------------------------|", 0Ah, 0
format7  DB "|   Instruction   |    Effect   |", 0Ah, 0
format8  DB "|-----------------|-------------|", 0Ah, 0
format9  DB "|   prefetcht0    | %     11.2f |", 0Ah, 0
format10 DB "|   prefetcht1    | %     11.2f |", 0Ah, 0
format11 DB "|   prefetcht2    | %     11.2f |", 0Ah, 0
format12 DB "|   prefetchw     | %     11.2f |", 0Ah, 0
format13 DB "|   prefetchnta   | %     11.2f |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
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
    @Call printf, OFFSET format5, CACHE_L1D_SIZE
    @Call printf, OFFSET format6
    @Call printf, OFFSET format7
    @Call printf, OFFSET format8

    mov @Param(3, DWORD), 4h    ; PAGE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), CACHE_LINE_SIZE + CACHE_L1D_SIZE
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    Row = 0

    REPEAT 5
        mov stack.measureAvg, 0
        mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

        clflush [rbp]
        xor r8, r8

        xor eax, eax
        cpuid

        ALIGN 16
    @@:
        IF Row EQ 0
            prefetcht0 [rbp + r8]
        ELSEIF Row EQ 1
            prefetcht1 [rbp + r8]
        ELSEIF Row EQ 2
            prefetcht2 [rbp + r8]
        ELSEIF Row EQ 3
            prefetchw [rbp + r8]
        ELSE
            prefetchnta [rbp + r8]
        ENDIF

        xor eax, eax
        cpuid

        mov eax, [rbp + r8]

        add r8, CACHE_LINE_SIZE
        cmp r8, CACHE_LINE_SIZE + CACHE_L1D_SIZE
        jb @B

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

        cmp rdx, MEASURE_ERROR_THRESHOLD
        ja @B

        add stack.measureAvg, rdx

        clflush [rbp]
        xor r8, r8

        xor eax, eax
        cpuid

        sub stack.measureRetryCountdown, 1
        jae @B

        mov rax, stack.measureAvg
        mov rdx, MEASURE_RETRY_AMOUNT
        cvtsi2sd xmm0, rax
        cvtsi2sd xmm1, rdx
        divsd xmm0, xmm1

        @Call printf, OFFSET @CatStr(format, %9 + Row), xmm0

        Row = Row + 1
    ENDM

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), CACHE_LINE_SIZE + CACHE_L1D_SIZE
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

END
