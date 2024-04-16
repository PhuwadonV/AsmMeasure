INCLUDELIB msvcrt.lib
INCLUDELIB legacy_stdio_definitions.lib

AMOUNT EQU 64

printf PROTO

.CONST
format DB "Result : %llu", 0Ah, 0

.CODE
main PROC
    push rsi
    push rdi
    sub rsp, 32

    rdtscp
    lfence
    mov esi, eax
    mov edi, edx

    REPEAT AMOUNT
        add eax, eax
    ENDM

    rdtscp
    lfence
    shl rdi, 32
    shl rdx, 32
    or rdi, rsi
    or rdx, rax
    sub rdx, rdi

    mov rcx, OFFSET format
    call printf

    xor eax, eax
    add rsp, 32
    pop rdi
    pop rsi
    ret
main ENDP

END
