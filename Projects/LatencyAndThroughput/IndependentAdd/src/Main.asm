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
format2 DB "|       Independent Add       |", 0Ah, 0
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
        AddAmount = (Row + ROW_OFFSET + 1) * ROW_SIZE

        @MeasureBegin

        I = 0

        REPEAT AddAmount
            IF I MOD 15 EQ 0
                add eax, eax
            ELSEIF I MOD 15 EQ 1
                add r8, r8
            ELSEIF I MOD 15 EQ 2
                add ebx, ebx
            ELSEIF I MOD 15 EQ 3
                add r9, r9
            ELSEIF I MOD 15 EQ 4
                add r10, r10
            ELSEIF I MOD 15 EQ 5
                add ecx, ecx
            ELSEIF I MOD 15 EQ 6
                add r11, r11
            ELSEIF I MOD 15 EQ 7
                add edx, edx
            ELSEIF I MOD 15 EQ 8
                add r12, r12
            ELSEIF I MOD 15 EQ 9
                add esi, esi
            ELSEIF I MOD 15 EQ 10
                add r13, r13
            ELSEIF I MOD 15 EQ 11
                add r14, r14
            ELSEIF I MOD 15 EQ 12
                add edi, edi
            ELSEIF I MOD 15 EQ 13
                add r15, r15
            ELSEIF I MOD 15 EQ 14
                add ebp, ebp
            ENDIF

            I = I + 1
        ENDM

        @MeasureEnd rdx

        mov rax, AddAmount
        cvtsi2sd xmm0, rax
        cvtsi2sd xmm1, rdx
        divsd xmm0, xmm1

        @Call printf, OFFSET format7, AddAmount, rdx, xmm0

        Row = Row + 1
    ENDM

    xor eax, eax
    @MeasureProcEnd
main ENDP

END
