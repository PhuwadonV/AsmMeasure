INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Measure.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

AMOUNT EQU 1024

printf PROTO

.CONST
format0 DB "|--------------------------------|", 0Ah, 0
format1 DB "|                                |", 0Ah, 0
format2 DB "| Measure Latency And Throughput |", 0Ah, 0
format3 DB "|                                |", 0Ah, 0
format4 DB "|--------------------------------|", 0Ah, 0
format5 DB "|  Amount  |   Cycle  |   Ratio  |", 0Ah, 0
format6 DB "|----------|----------|----------|", 0Ah, 0
format7 DB "| %   8llu | %   8llu | %   8.2f |", 0Ah, 0

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

    @MeasureBegin
    REPEAT AMOUNT
        add eax, eax
    ENDM
    @MeasureEnd rdx

    mov rax, AMOUNT
    cvtsi2sd xmm0, rax
    cvtsi2sd xmm1, rdx
    divsd xmm0, xmm1

    @Call printf, OFFSET format7, AMOUNT, rdx, xmm0

    xor eax, eax
    @MeasureProcEnd
main ENDP

END
