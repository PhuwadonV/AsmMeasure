INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Thread.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

WORK_SIZE                   EQU 500000
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

I = 0

REPEAT 5
    @CatStr(DoWorkParallel, %I) PROTO

    I = I + 1
ENDM

.CONST
format0 DB  "|---------------------------------|", 0Ah, 0
format1 DB  "|                                 |", 0Ah, 0
format2 DB  "|        Atomic Instruction       |", 0Ah, 0
format3 DB  "|                                 |", 0Ah, 0
format4 DB  "|---------------------------------|", 0Ah, 0
format5 DB  "| Atomic | Instruction |  Result  |", 0Ah, 0
format6 DB  "|--------|-------------|----------|", 0Ah, 0
format7 DB  "|  True  |   xchg      | %   8llu |", 0Ah, 0
format8 DB  "|  False |   cmpxchg   | %   8llu |", 0Ah, 0
format9 DB  "|  True  |   cmpxchg   | %   8llu |", 0Ah, 0
format10 DB "|  False |   add       | %   8llu |", 0Ah, 0
format11 DB "|  True  |   add       | %   8llu |", 0Ah, 0

.DATA
step     DD ?
occupied DD 0
result   DD 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        threadHandle QWORD ?
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

    Row = 0

    REPEAT 5
        mov step, STEP_INITIALIZING
        mov result, 0
        @Call CreateSimpleThread, @CatStr(DoWorkParallel, %Row)
        mov stack.threadHandle, rax
        @Sync step, STEP_INITIALIZED

        mov step, STEP_PREPARING
        @Sync step, STEP_PREPARED

        mov step, STEP_PROCESSING

        call @CatStr(DoWork, %Row)

        @Sync step, STEP_PROCESSED

        mov @Param(1, DWORD), -1
        mov @Param(0, QWORD), stack.threadHandle
        call __imp_WaitForSingleObject

        @Call printf, OFFSET @CatStr(format, %7 + Row), result

        Row = Row + 1
    ENDM

    xor eax, eax
    @ProcEnd
main ENDP

I = 0

REPEAT 5
    @CatStr(DoWork, %I) PROC
        @ProcBegin

        mov eax, 1
        mov ecx, WORK_SIZE - 1
        pause

        ALIGN 16
    @@:
        IF I EQ 0
            pause
            cmp occupied, 0
            jne @B

            mov eax, 1
            xchg occupied, eax
            test eax, eax
            jnz @B

            add result, 1
            mov occupied, 0
        ELSEIF I EQ 1
            mov eax, result
            lea edx, [eax + 1]
            cmpxchg result, edx
            jne @B
        ELSEIF I EQ 2
            mov eax, result
            lea edx, [eax + 1]
            lock cmpxchg result, edx
            jne @B
        ELSEIF I EQ 3
            add result, eax
        ELSE
            lock add result, eax
        ENDIF
        
        sub ecx, 1
        jae @B

        xor eax, eax
        @ProcEnd
    @CatStr(DoWork, %I) ENDP

    @CatStr(DoWorkParallel, %I) PROC
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

        mov step, STEP_PREPARED
        @Sync step, STEP_PROCESSING

        call @CatStr(DoWork, %I)

        mov step, STEP_PROCESSED

        xor eax, eax
        @ProcEnd
    @CatStr(DoWorkParallel, %I) ENDP

    I = I + 1
ENDM

END
