INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT           EQU 16
ROW_OFFSET           EQU 0
MEASURE_RETRY_AMOUNT EQU 0FFFh

printf PROTO
EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR
EXTERNDEF __imp_VirtualAlloc         : PTR
EXTERNDEF __imp_VirtualFree          : PTR

.CONST
format0 DB "|--------------------------------|", 0Ah, 0
format1 DB "|                                |", 0Ah, 0
format2 DB "| Read From Write Combine Memory |", 0Ah, 0
format3 DB "|                                |", 0Ah, 0
format4 DB "|--------------------------------|", 0Ah, 0
format5 DB "|          |        Effect       |", 0Ah, 0
format6 DB "|   Bytes  |---------------------|", 0Ah, 0
format7 DB "|          |  movdqa  | movntdqa |", 0Ah, 0
format8 DB "|----------|----------|----------|", 0Ah, 0
format9 DB "| %   8llu | %   8llu | %   8llu |", 0Ah, 0

.CODE
main PROC PUBLIC
    Stack_main STRUCT
        STRUCT measure
            temporal          QWORD ?
            nonTemporal       QWORD ?
        ENDS
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
    @Call printf, OFFSET format7
    @Call printf, OFFSET format8

    mov @Param(3, DWORD), 404h ; PAGE_READWRITE | PAGE_WRITECOMBINE
    mov @Param(2, DWORD), 1000h ; MEM_COMMIT
    mov @Param(1, DWORD), (ROW_AMOUNT + ROW_OFFSET) * 16
    mov @Param(0, DWORD), 0
    call __imp_VirtualAlloc
    mov rbp, rax

    Row = 0

    REPEAT ROW_AMOUNT
        Column = 0

        REPEAT 2
            @Var QWORD, measureMin, stack.measure[8 * Column]

            mov measureMin, -1
            mov stack.measureRetryCountdown, MEASURE_RETRY_AMOUNT

            ALIGN 16
        @@:
            xor eax, eax
            cpuid

            rdtscp
            lfence
            mov esi, eax
            mov edi, edx

            IF Column EQ 0
                Op TEXTEQU <movdqa>
            ELSE
                Op TEXTEQU <movntdqa>
            ENDIF

            I = 0
            
            REPEAT (Row + ROW_OFFSET) + 1
                Op xmm0, XMMWORD PTR [rbp + I * 16]

                I = I + 1
            ENDM

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

            Column = Column + 1
        ENDM

        @Call printf, OFFSET format9, (Row + ROW_OFFSET + 1) * 16, stack.measure.temporal, stack.measure.nonTemporal

        Row = Row + 1
    ENDM

    mov @Param(2, DWORD), 4000h ; MEM_DECOMMIT
    mov @Param(1, DWORD), (ROW_AMOUNT + ROW_OFFSET) * 16
    mov @Param(0, QWORD), rbp
    call __imp_VirtualFree

    xor eax, eax
    @ProcEnd
main ENDP

END
