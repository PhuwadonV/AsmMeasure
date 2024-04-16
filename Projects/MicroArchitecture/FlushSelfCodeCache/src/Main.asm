INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT EQU 0FFFh
DELAY_FETCH_BYTES    EQU 1000h

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0 DB "|----------------------------------|", 0Ah, 0
format1 DB "|                                  |", 0Ah, 0
format2 DB "|       Flush Self Code Cache      |", 0Ah, 0
format3 DB "|                                  |", 0Ah, 0
format4 DB "|----------------------------------|", 0Ah, 0
format5 DB "| Position in cache line |  Effect |", 0Ah, 0
format6 DB "|------------------------|---------|", 0Ah, 0
format7 DB "|          First         | %  7llu |", 0Ah, 0
format8 DB "|          Last          | %  7llu |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ?
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

    mov @Param(3, DWORD), 40h   ; PAGE_EXECUTE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), CACHE_LINE_SIZE * 2
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    mov DWORD PTR [rbp + CACHE_LINE_SIZE], 0001F66C3h ; ret

    Row = 0

    REPEAT 2
        mov stack.measureMin, -1
        mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

        mov ecx, (CACHE_LINE_SIZE / 4) - 1

        ALIGN 16
    @@:
        mov DWORD PTR [rbp + rcx * 4], 00401F0Fh ; nop

        sub ecx, 1
        jae @B

        IF Row EQ 0
            mov DWORD PTR [rbp],                       007DAE0Fh ; clflush [rbp]
        ELSE
            mov DWORD PTR [rbp + CACHE_LINE_SIZE - 4], 007DAE0Fh ; clflush [rbp]
        ENDIF

        ALIGN 16
    @@:
        clflush [rbp]
        mfence
        call rbp

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

        cmp rdx, stack.measureMin
        cmova rdx, stack.measureMin
        mov stack.measureMin, rdx

        call DelayFetch

        sub stack.measureRetryCountdown, 1
        jae @B

        @Call printf, OFFSET @CatStr(format, %7 + Row), stack.measureMin

        Row = Row + 1
    ENDM

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), CACHE_LINE_SIZE * 2
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

DelayFetch PROC
    REPEAT DELAY_FETCH_BYTES
        nop
    ENDM

    ret
DelayFetch ENDP

END
