INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Measure.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT EQU 16
ROW_OFFSET EQU 0
ROW_SIZE   EQU 512

printf PROTO

.CONST
format0 DB "|-----------------------------|", 0Ah, 0
format1 DB "|                             |", 0Ah, 0
format2 DB "|          Empty Proc         |", 0Ah, 0
format3 DB "|                             |", 0Ah, 0
format4 DB "|-----------------------------|", 0Ah, 0
format5 DB "|  Amount |  Cycle  |  Ratio  |", 0Ah, 0
format6 DB "|---------|---------|---------|", 0Ah, 0
format7 DB "| %  7llu | %  7llu | %  7.2f |", 0Ah, 0

.CODE
main PROC PUBLIC
    @MeasureProcBegin
    @MeasureInit

    @Call printf, OFFSET format0
    @Call printf, OFFSET format1
    @Call printf, OFFSET format2
    @Call printf, OFFSET format3
    @Call printf, OFFSET format4
    @Call printf, OFFSET format5
    @Call printf, OFFSET format6

    Row = 0

    REPEAT ROW_AMOUNT
        ProcAmount = (Row + ROW_OFFSET + 1) * ROW_SIZE

        @MeasureBegin
        REPEAT ProcAmount
            call EmptyProc
        ENDM
        @MeasureEnd rdx

        mov rax, ProcAmount
        cvtsi2sd xmm0, rdx
        cvtsi2sd xmm1, rax
        divsd xmm0, xmm1

        @Call printf, OFFSET format7, ProcAmount, rdx, xmm0

        Row = Row + 1
    ENDM

    xor eax, eax
    @MeasureProcEnd
main ENDP

EmptyProc PROC
    ret
EmptyProc ENDP

END
