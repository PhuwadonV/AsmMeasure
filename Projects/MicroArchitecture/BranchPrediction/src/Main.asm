INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT     EQU 0FFFh
MEMORY_LATENCY_THRESHOLD EQU 60h

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR

.CONST
format0 DB "|-----------------------------|", 0Ah, 0
format1 DB "|                             |", 0Ah, 0
format2 DB "|      Branch Prediction      |", 0Ah, 0
format3 DB "|                             |", 0Ah, 0
format4 DB "|-----------------------------|", 0Ah, 0
format5 DB "|   Miss  |   Hit   |   Diff  |", 0Ah, 0
format6 DB "|---------|---------|---------|", 0Ah, 0
format7 DB "| %  7llu | %  7llu | %  7llu |", 0Ah, 0

.DATA
memory DD ?

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        STRUCT measure
            hit               QWORD ?
            miss              QWORD ?
        ENDS
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

    Column = 0

    REPEAT 2
        LOCAL Training

        @Var QWORD, measureMin, stack.measure[8 * Column]

        mov measureMin, -1
        mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

        ALIGN 16
    @@:
        IF Column EQ 0
            mov ebp, 1
        ELSE
            rdrand ebp
            and ebp, 0FFh
            add ebp, 0FFh
        ENDIF

        xor eax, eax
        cpuid

        ALIGN 16
    Training:
        mov eax, memory
        lfence

        pause
        lfence

        clflush memory
        xor eax, eax
        cpuid

        rdtscp
        lfence
        mov esi, eax
        mov edi, edx

        sub ebp, 1
        jae Training

        rdtscp
        lfence
        shl rdi, 32
        shl rdx, 32
        or rdi, rsi
        or rdx, rax
        sub rdx, rdi
        mov r8, rdx

        xor eax, eax
        cpuid

        rdtscp
        lfence
        mov esi, eax
        mov edi, edx

        mov eax, [memory]

        rdtscp
        lfence
        shl rdi, 32
        shl rdx, 32
        or rdi, rsi
        or rdx, rax
        sub rdx, rdi

        cmp rdx, MEMORY_LATENCY_THRESHOLD

        IF Column EQ 0
            jb @B
        ELSE
            ja @B
        ENDIF

        cmp r8, measureMin
        cmova r8, measureMin
        mov measureMin, r8

        sub stack.measureRetryCountdown, 1
        jae @B

        Column = Column + 1
    ENDM

    @Var QWORD, diff, @Param(3, QWORD)
    mov diff, stack.measure.miss
    sub diff, stack.measure.hit

    @Call printf, OFFSET format7, stack.measure.miss, stack.measure.hit

    xor eax, eax
    @ProcEnd
main ENDP

END
