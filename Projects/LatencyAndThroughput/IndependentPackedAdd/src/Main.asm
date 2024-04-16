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
format2 DB "|    Independent Packed Add   |", 0Ah, 0
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
        PackedAddAmount = (Row + ROW_OFFSET + 1) * ROW_SIZE

        @MeasureBegin

        I = 0

        REPEAT PackedAddAmount
            IF I MOD 15 EQ 0
                paddd xmm0, xmm0
            ELSEIF I MOD 16 EQ 1
                paddd xmm1, xmm1
            ELSEIF I MOD 16 EQ 2
                paddd xmm2, xmm2
            ELSEIF I MOD 16 EQ 3
                paddd xmm3, xmm3
            ELSEIF I MOD 16 EQ 4
                paddd xmm4, xmm4
            ELSEIF I MOD 16 EQ 5
                paddd xmm5, xmm5
            ELSEIF I MOD 16 EQ 6
                paddd xmm6, xmm6
            ELSEIF I MOD 16 EQ 7
                paddd xmm7, xmm7
            ELSEIF I MOD 16 EQ 8
                paddd xmm8, xmm8
            ELSEIF I MOD 16 EQ 9
                paddd xmm9, xmm9
            ELSEIF I MOD 16 EQ 10
                paddd xmm10, xmm10
            ELSEIF I MOD 16 EQ 11
                paddd xmm11, xmm11
            ELSEIF I MOD 16 EQ 12
                paddd xmm12, xmm12
            ELSEIF I MOD 16 EQ 13
                paddd xmm13, xmm13
            ELSEIF I MOD 16 EQ 14
                paddd xmm14, xmm14
            ELSEIF I MOD 16 EQ 15
                paddd xmm15, xmm15
            ENDIF

            I = I + 1
        ENDM

        @MeasureEnd rdx

        mov rax, PackedAddAmount
        cvtsi2sd xmm0, rax
        cvtsi2sd xmm1, rdx
        divsd xmm0, xmm1

        @Call printf, OFFSET format7, PackedAddAmount, rdx, xmm0

        Row = Row + 1
    ENDM

    xor eax, eax
    @MeasureProcEnd
main ENDP

END
