INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Thread.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT        EQU 0FFFh
MEASURE_ERROR_THRESHOLD     EQU 1000
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
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

I = 0

REPEAT 10
    @CatStr(DoWorkParallel, %I) PROTO

    I = I + 1
ENDM

.CONST
format0  DB "|-----------------------------------------------------------------------------------------|", 0Ah, 0
format1  DB "|                                                                                         |", 0Ah, 0
format2  DB "|                           Shared Memory Latency After Prefetch                          |", 0Ah, 0
format3  DB "|                                                                                         |", 0Ah, 0
format4  DB "|-----------------------------------------------------------------------------------------|", 0Ah, 0
format5  DB "|#|    Worker Thread    |#|                         Main Thread                         |#|", 0Ah, 0
format6  DB "|#|---------------------|#|-------------------------------------------------------------|#|", 0Ah, 0
format7  DB "|#|                     |#|             Min             |#|             Avg             |#|", 0Ah, 0
format8  DB "|#|       Previous      |#|-----------------------------|#|-----------------------------|#|", 0Ah, 0
format9  DB "|#|                     |#|  Flush  |   Read  |  Write  |#|  Flush  |   Read  |  Write  |#|", 0Ah, 0
format10 DB "|#|---------------------|#|---------|---------|---------|#|---------|---------|---------|#|", 0Ah, 0
format11 DB "|#| Flush | prefetcht0  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format12 DB "|#| Flush | prefetcht1  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format13 DB "|#| Flush | prefetcht2  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format14 DB "|#| Flush | prefetchw   |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format15 DB "|#| Flush | prefetchnta |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format16 DB "|#|---------------------|#|-----------------------------|#|-----------------------------|#|", 0Ah, 0
format17 DB "|#|       | prefetcht0  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format18 DB "|#|       | prefetcht1  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format19 DB "|#|       | prefetcht2  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format20 DB "|#|       | prefetchw   |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format21 DB "|#|       | prefetchnta |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0

.DATA
step  DD ?
retry DD FALSE

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        threadHandle          QWORD ?
        STRUCT measure
            flushMin          QWORD ?
            readMin           QWORD ?
            writeMin          QWORD ?
            flushAvg          QWORD ?
            readAvg           QWORD ?
            writeAvg          QWORD ?
        ENDS
        measureRetryCountdown DWORD ?
    Stack_main ENDS

    MaxParam_main = 7
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
    @Call printf, OFFSET format7
    @Call printf, OFFSET format8
    @Call printf, OFFSET format9
    @Call printf, OFFSET format10

    mov @Param(3, DWORD), 4h    ; PAGE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    Row = 0

    REPEAT 10
        Column = 0

        mov step, STEP_INITIALIZING
        mov retry, TRUE
        @Call CreateSimpleThread, @CatStr(DoWorkParallel, %Row), rbp
        mov stack.threadHandle, rax
        @Sync step, STEP_INITIALIZED

        REPEAT 6
            @Var QWORD, measureCycle, stack.measure[8 * Column]

            IF Column LT 3
                mov measureCycle, -1
            ELSE
                mov measureCycle, 0
            ENDIF

            mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

            ALIGN 16
        @@:
            mov step, STEP_PREPARING
            @Sync step, STEP_PREPARED

            mov step, STEP_PROCESSING
            @Sync step, STEP_PROCESSED

            xor eax, eax
            cpuid

            rdtscp
            lfence
            mov esi, eax
            mov edi, edx

            IF Column MOD 3 EQ 0
                clflush [rbp]
                mfence
            ELSEIF Column MOD 3 EQ 1
                mov eax, [rbp]
            ELSE
                mov [rbp], eax
                mfence
            ENDIF

            rdtscp
            lfence
            shl rdi, 32
            shl rdx, 32
            or rdi, rsi
            or rdx, rax
            sub rdx, rdi

            cmp rdx, MEASURE_ERROR_THRESHOLD
            ja @B

            IF Column LT 3
                cmp rdx, measureCycle
                cmova rdx, measureCycle
                mov measureCycle, rdx
            ELSE
                add measureCycle, rdx
            ENDIF

            sub stack.measureRetryCountdown, 1
            jae @B

            IF Column GT 2
                mov rax, measureCycle
                mov rdx, MEASURE_RETRY_AMOUNT
                cvtsi2sd xmm0, rax
                cvtsi2sd xmm1, rdx
                divsd xmm0, xmm1
                movq measureCycle, xmm0
            ENDIF

            Column = Column + 1
        ENDM

        mov retry, FALSE
        mov step, STEP_PREPARING

        mov @Param(1, DWORD), -1
        mov @Param(0, QWORD), stack.threadHandle
        call __imp_WaitForSingleObject

        mov rax, stack.measure.writeAvg
        mov rcx, stack.measure.readAvg
        mov rdx, stack.measure.flushAvg
        mov @Param(6, QWORD), rax
        mov @Param(5, QWORD), rcx
        mov @Param(4, QWORD), rdx
        mov @Param(3, QWORD), stack.measure.writeMin
        mov @Param(2, QWORD), stack.measure.readMin
        mov @Param(1, QWORD), stack.measure.flushMin

        @Call printf, OFFSET @CatStr(format, %11 + Row + Row / 5)

        IF Row EQ 4
            @Call printf, OFFSET format16
        ENDIF

        Row = Row + 1
    ENDM

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

I = 0

REPEAT 10
    @CatStr(DoWorkParallel, %I) PROC
        MaxParam_DoWorkParallel = 4
        @ProcBegin 8 * MaxParam_DoWorkParallel, rbp

        mov rbp, @Arg(0, QWORD)

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

        IF I LT 5
            clflush [rbp]
            xor eax, eax
            cpuid
        ENDIF

        IF I MOD 5 EQ 0
            prefetcht0 [rbp]
        ELSEIF I MOD 5 EQ 1
            prefetcht1 [rbp]
        ELSEIF I MOD 5 EQ 2
            prefetcht2 [rbp]
        ELSEIF I MOD 5 EQ 3
            prefetchw [rbp]
        ELSE
            prefetchnta [rbp]
        ENDIF

        xor eax, eax
        cpuid

        mov step, STEP_PROCESSED
        @Sync step, STEP_PREPARING

        cmp retry, FALSE
        jne @B

        xor eax, eax
        @ProcEnd
    @CatStr(DoWorkParallel, %I) ENDP

    I = I + 1
ENDM

END
