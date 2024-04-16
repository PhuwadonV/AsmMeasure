INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT EQU 0FFFh

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR

.CONST
format0 DB "|----------------------------|", 0Ah, 0
format1 DB "|                            |", 0Ah, 0
format2 DB "| Cache Pollution From Write |", 0Ah, 0
format3 DB "|                            |", 0Ah, 0
format4 DB "|----------------------------|", 0Ah, 0
format5 DB "|    Temporal   |   Effect   |", 0Ah, 0
format6 DB "|---------------|------------|", 0Ah, 0
format7 DB "|      Yes      | %    10llu |", 0Ah, 0
format8 DB "|      No       | %    10llu |", 0Ah, 0

.DATA
memory DD ?

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        measureMin            QWORD ?
        measureRetryCountdown DWORD ?
    Stack_main ENDS

    MaxParam_main = 4
    @ProcBegin 8 * MaxParam_main + SIZE(Stack_main), rsi, rdi

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

    Row = 0

    REPEAT 2
        mov stack.measureMin, -1
        mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

        ALIGN 16
    @@:
        clflush memory

        IF Row EQ 0
            mov memory, eax
        ELSE
            movnti memory, eax
        ENDIF

        xor eax, eax
        cpuid

        rdtscp
        lfence
        mov esi, eax
        mov edi, edx

        mov eax, memory

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

        @Call printf, OFFSET @CatStr(format, %7 + Row), rdx

        Row = Row + 1
    ENDM

    xor eax, eax
    @ProcEnd
main ENDP

END
