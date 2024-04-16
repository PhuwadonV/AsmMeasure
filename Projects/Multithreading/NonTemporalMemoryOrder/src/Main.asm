INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Thread.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT        EQU 100000
WRITE_AMOUNT                EQU 32
WORKER_THREAD_AFFINITY_MASK EQU 1 SHL 2

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

DoWorkParallel PROTO

.CONST
format0 DB "|---------------------------|", 0Ah, 0
format1 DB "|                           |", 0Ah, 0
format2 DB "| Non Temporal Memory Order |", 0Ah, 0
format3 DB "|                           |", 0Ah, 0
format4 DB "|---------------------------|", 0Ah, 0
format5 DB "|     Fence     |   Error   |", 0Ah, 0
format6 DB "|---------------|-----------|", 0Ah, 0
format7 DB "|     sfence    | %    9llu |", 0Ah, 0
format8 DB "|     [none]    | %    9llu |", 0Ah, 0

.DATA
step   DD ?
retry  DD FALSE
memory DD WRITE_AMOUNT DUP(?)
error  DD 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        threadHandle          QWORD ?
        measureRetryCountdown DWORD ?
    Stack_main ENDS

    MaxParam_main = 4
    @ProcBegin 8 * MaxParam_main + SIZE(Stack_main)

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

    mov step, STEP_INITIALIZING
    mov retry, TRUE
    @Call CreateSimpleThread, DoWorkParallel
    mov stack.threadHandle, rax
    @Sync step, STEP_INITIALIZED

    Row = 0

    REPEAT 2
        mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

        ALIGN 16
    @@:
        mov step, STEP_PREPARING
        @Sync step, STEP_PREPARED

        prefetchw step
        xor eax, eax

        I = 0

        REPEAT WRITE_AMOUNT
            movnti [memory + I * 4], eax

            I = I + 1
        ENDM

        IF Row EQ 0
            sfence
        ENDIF

        mov step, STEP_PROCESSING
        @Sync step, STEP_PROCESSED

        mov [memory + (WRITE_AMOUNT - 1) * 4], 1

        sub stack.measureRetryCountdown, 1
        jae @B

        @Call printf, OFFSET @CatStr(format, %7 + Row), error

        Row = Row + 1
    ENDM

    mov retry, FALSE
    mov step, STEP_PREPARING

    mov @Param(1, DWORD), -1
    mov @Param(0, QWORD), stack.threadHandle
    call __imp_WaitForSingleObject

    xor eax, eax
    @ProcEnd
main ENDP

DoWorkParallel PROC
    MaxParam_DoWorkParallel = 4
    @ProcBegin 8 * MaxParam_DoWorkParallel

    call __imp_GetCurrentThread
    mov @Param(1, QWORD), WORKER_THREAD_AFFINITY_MASK
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

    mov eax, [memory + (WRITE_AMOUNT - 1) * 4]
    add error, eax

    mov step, STEP_PROCESSED
    @Sync step, STEP_PREPARING

    cmp retry, FALSE
    jne @B

    xor eax, eax
    @ProcEnd
DoWorkParallel ENDP

END
