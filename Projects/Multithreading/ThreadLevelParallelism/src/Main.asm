INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Thread.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT           EQU 16
WORK_SIZE_LARGE      EQU 1000
WORK_SIZE_SMALL      EQU 10
MEASURE_RETRY_AMOUNT EQU 0FFFh

STEP_INITIALIZING EQU 0
STEP_INITIALIZED  EQU 1
STEP_PREPARING    EQU 2
STEP_PREPARED     EQU 3
STEP_PROCESSING   EQU 4
STEP_PROCESSED    EQU 5

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_WaitForSingleObject  : PTR

DoWork         PROTO
DoWorkParallel PROTO

.CONST
format0 DB "|-----------------------------------------------|", 0Ah, 0
format1 DB "|                                               |", 0Ah, 0
format2 DB "|            Thread Level Parallelism           |", 0Ah, 0
format3 DB "|                                               |", 0Ah, 0
format4 DB "|-----------------------------------------------|", 0Ah, 0
format5 DB "| Execution | Thread | Thread |  Large |  Small |", 0Ah, 0
format6 DB "|-----------|--------|--------|--------|--------|", 0Ah, 0
format7 DB "|  Serial   |      0 |      0 | % 6llu | % 6llu |", 0Ah, 0
format8 DB "|  Parallel |      0 | % 6llu | % 6llu | % 6llu |", 0Ah, 0

.DATA
step  DD ?
retry DD FALSE

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        threadHandle          QWORD ?
        STRUCT measure
            large             QWORD ?
            small             QWORD ?
        ENDS
        measureRetryCountdown DWORD ?
        workSize              DWORD ?
        threadAffinityMask    QWORD ?
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

    REPEAT ROW_AMOUNT
        Column = 0

        REPEAT 2
            @Var QWORD, measureMin, stack.measure[8 * Column]

            IF Column EQ 0
                WorkSize = WORK_SIZE_LARGE
            ELSE
                WorkSize = WORK_SIZE_SMALL
            ENDIF

            mov measureMin, -1
            mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

            IF Row GT 0
                mov step, STEP_INITIALIZING
                mov retry, TRUE
                mov stack.workSize, WorkSize
                mov stack.threadAffinityMask, 1 SHL Row
                @Call CreateSimpleThread, DoWorkParallel, rsp
                mov stack.threadHandle, rax
                @Sync step, STEP_INITIALIZED
            ENDIF

            ALIGN 16
        @@:
            IF Row GT 0
                mov step, STEP_PREPARING
                @Sync step, STEP_PREPARED
            ENDIF

            xor eax, eax
            cpuid

            rdtscp
            lfence
            mov esi, eax
            mov edi, edx

            IF Row EQ 0
                mov @Param(0, DWORD), WorkSize * 2
                call DoWork
            ELSE
                mov step, STEP_PROCESSING
                mov @Param(0, DWORD), WorkSize
                call DoWork
                @Sync step, STEP_PROCESSED
            ENDIF

            rdtscp
            lfence
            shl rdi, 32
            shl rdx, 32
            or rdi, rsi
            or rdx, rax
            sub rdx, rdi

            cmp rdx, measureMin
            cmova rdx, measureMin
            mov measureMin, rdx

            sub stack.measureRetryCountdown, 1
            jae @B

            IF Row GT 0
                mov retry, FALSE
                mov step, STEP_PREPARING
            ENDIF

            IF Row GT 0
                mov @Param(1, DWORD), -1
                mov @Param(0, QWORD), stack.threadHandle
                call __imp_WaitForSingleObject
            ENDIF

            Column = Column + 1
        ENDM

        IF Row EQ 0
            mov @Param(2, QWORD), stack.measure.small
            mov @Param(1, QWORD), stack.measure.large
            mov @Param(0, QWORD), OFFSET format7
        ELSE
            mov @Param(3, QWORD), stack.measure.small
            mov @Param(2, QWORD), stack.measure.large
            mov @Param(1, DWORD), Row
            mov @Param(0, QWORD), OFFSET format8
        ENDIF
        call printf

        Row = Row + 1
    ENDM

    xor eax, eax
    @ProcEnd
main ENDP

DoWork PROC
    @ProcBegin

    ALIGN 16
@@:
    mov eax, 2
    xor edx, edx
    div eax
    sub ecx, 1
    jae @B

    xor eax, eax
    @ProcEnd
DoWork ENDP

DoWorkParallel PROC
    MaxParam_DoWorkParallel = 4
    @ProcBegin 8 * MaxParam_DoWorkParallel, rbp

    mov rbp, @Arg(0, QWORD)

    call __imp_GetCurrentThread
    mov @Param(1, QWORD), (Stack_main PTR [rbp + 8 * MaxParam_main]).threadAffinityMask
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

    mov step, STEP_INITIALIZED
    @Sync step, STEP_PREPARING

    ALIGN 16
@@:
    mov step, STEP_PREPARED
    @Sync step, STEP_PROCESSING

    mov @Param(0, DWORD), (Stack_main PTR [rbp + 8 * MaxParam_main]).workSize
    call DoWork

    mov step, STEP_PROCESSED
    @Sync step, STEP_PREPARING

    cmp retry, FALSE
    jne @B

    xor eax, eax
    @ProcEnd
DoWorkParallel ENDP

END
