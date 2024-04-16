INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib
INCLUDE Util/Core.inc
INCLUDE Util/Measure.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

ROW_AMOUNT EQU 16
ROW_OFFSET EQU 0
ROW_SIZE   EQU 4096

printf PROTO

.CONST
format0 DB "|-----------------------------|", 0Ah, 0
format1 DB "|                             |", 0Ah, 0
format2 DB "|       Bytes Per Cycle       |", 0Ah, 0
format3 DB "|                             |", 0Ah, 0
format4 DB "|-----------------------------|", 0Ah, 0
format5 DB "|  Bytes  |  Cycle  |  Ratio  |", 0Ah, 0
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
        NopAmount = ((Row + ROW_OFFSET + 1) * ROW_SIZE) / 8
        Bytes     = NopAmount * 8

        @MeasureBegin
        REPEAT NopAmount
            DB 0Fh, 1Fh, 84h, 00h, 00h, 00h, 00h, 00h ; nop
        ENDM
        @MeasureEnd rdx

        mov rax, Bytes
        cvtsi2sd xmm0, rax
        cvtsi2sd xmm1, rdx
        divsd xmm0, xmm1

        @Call printf, OFFSET format7, Bytes, rdx, xmm0

        Row = Row + 1
    ENDM

    xor eax, eax
    @MeasureProcEnd
main ENDP

END
