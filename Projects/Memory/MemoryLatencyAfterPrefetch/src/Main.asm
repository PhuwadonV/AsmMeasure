INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

MEASURE_RETRY_AMOUNT    EQU 0FFFh
MEASURE_ERROR_THRESHOLD EQU 1000

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0  DB "|-----------------------------------------------------------------------------------------|", 0Ah, 0
format1  DB "|                                                                                         |", 0Ah, 0
format2  DB "|                              Memory Latency After Prefetch                              |", 0Ah, 0
format3  DB "|                                                                                         |", 0Ah, 0
format4  DB "|-----------------------------------------------------------------------------------------|", 0Ah, 0
format5  DB "|#|                     |#|             Min             |#|             Avg             |#|", 0Ah, 0
format6  DB "|#|       Previous      |#|-----------------------------|#|-----------------------------|#|", 0Ah, 0
format7  DB "|#|                     |#|  Flush  |   Read  |  Write  |#|  Flush  |   Read  |  Write  |#|", 0Ah, 0
format8  DB "|#|---------------------|#|---------|---------|---------|#|---------|---------|---------|#|", 0Ah, 0
format9  DB "|#| Flush | prefetcht0  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format10 DB "|#| Flush | prefetcht1  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format11 DB "|#| Flush | prefetcht2  |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format12 DB "|#| Flush | prefetchw   |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0
format13 DB "|#| Flush | prefetchnta |#| %  7llu | %  7llu | %  7llu |#| %  7.2f | %  7.2f | %  7.2f |#|", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
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

    mov @Param(3, DWORD), 4h    ; PAGE_READWRITE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    Row = 0

    REPEAT 5
        Column = 0

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
            clflush [rbp]
            xor eax, eax
            cpuid

            IF Row EQ 0
                prefetcht0 [rbp]
            ELSEIF Row EQ 1
                prefetcht1 [rbp]
            ELSEIF Row EQ 2
                prefetcht2 [rbp]
            ELSEIF Row EQ 3
                prefetchw [rbp]
            ELSEIF Row EQ 4
                prefetchnta [rbp]
            ENDIF

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

        mov rax, stack.measure.writeAvg
        mov rcx, stack.measure.readAvg
        mov rdx, stack.measure.flushAvg
        mov @Param(6, QWORD), rax
        mov @Param(5, QWORD), rcx
        mov @Param(4, QWORD), rdx
        mov @Param(3, QWORD), stack.measure.writeMin
        mov @Param(2, QWORD), stack.measure.readMin
        mov @Param(1, QWORD), stack.measure.flushMin

        @Call printf, OFFSET @CatStr(format, %9 + Row)

        Row = Row + 1
    ENDM

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), 4
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

END
