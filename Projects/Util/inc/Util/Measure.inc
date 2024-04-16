IFNDEF UTIL_MEASURE_INC
UTIL_MEASURE_INC EQU -1

EXTERNDEF __imp_GetCurrentThread     : PTR
EXTERNDEF __imp_GetCurrentProcess    : PTR
EXTERNDEF __imp_SetThreadAffinityMask: PTR
EXTERNDEF __imp_SetPriorityClass     : PTR
EXTERNDEF __imp_SetThreadPriority    : PTR

@MeasureProcBegin MACRO Size:=<8 * 4>
    StackSize = (Size) + 8 * 5 + 4 * 1
    StackSize = StackSize + (16 - (StackSize + 8) MOD 16) MOD 16

    push rbx
    push r12
    push rbp
    push r13
    push rsi
    push r14
    push rdi
    push r15
    sub  rsp, StackSize
ENDM

@MeasureProcEnd MACRO
    add rsp, StackSize
    pop r15
    pop rdi
    pop r14
    pop rsi
    pop r13
    pop rbp
    pop r12
    pop rbx
    ret
ENDM

@MeasureInit MACRO Mask:=<1>
    call __imp_GetCurrentProcess
    mov @Param(1, DWORD), 100h
    mov @Param(0, QWORD), rax
    call __imp_SetPriorityClass

    call __imp_GetCurrentThread
    mov @Param(1, DWORD), 15
    mov @Param(0, QWORD), rax
    call __imp_SetThreadPriority

    call __imp_GetCurrentThread
    mov rcx, rax
    mov rdx, Mask
    call __imp_SetThreadAffinityMask
ENDM

@MeasureBegin MACRO ErrorThreshold:=<-1>, RetryAmount:=<0FFFh>
    LOCAL RetryLoop

    MeasureErrorThreshold = ErrorThreshold
    MeasureRetryAmount    = RetryAmount
    MeasureRetryLoop      TEXTEQU <RetryLoop>
    MeasureCycle          TEXTEQU <QWORD PTR [rsp + StackSize - 8 * 1 - 4 * 0]>
    MeasureMin            TEXTEQU <QWORD PTR [rsp + StackSize - 8 * 2 - 4 * 0]>
    MeasureAvg            TEXTEQU <QWORD PTR [rsp + StackSize - 8 * 3 - 4 * 0]>
    MeasureMax            TEXTEQU <QWORD PTR [rsp + StackSize - 8 * 4 - 4 * 0]>
    MeasureErr            TEXTEQU <QWORD PTR [rsp + StackSize - 8 * 5 - 4 * 0]>
    MeasureRetryCountdown TEXTEQU <DWORD PTR [rsp + StackSize - 8 * 5 - 4 * 1]>

    mov MeasureMin, -1
    mov MeasureAvg, 0
    mov MeasureMax, 0
    mov MeasureErr, 0
    mov MeasureRetryCountdown, RetryAmount

    ALIGN 16
RetryLoop:
    lea rdi, MeasureCycle

    xor eax, eax
    cpuid

    ALIGN 16
    rdtscp
    lfence
    shl rdx, 32
    or rax, rdx
    mov [rdi], rax

    ALIGN 16
ENDM

@MeasureEnd MACRO Min, Avg, Max, Err
    ALIGN 16
    rdtscp
    lfence
    shl rdx, 32
    or rax, rdx
    sub rax, MeasureCycle

    mov rcx, MeasureErr
    mov rdx, rcx
    inc rdx
    cmp rax, MeasureErrorThreshold
    cmova rcx, rdx
    mov MeasureErr, rcx 
    ja MeasureRetryLoop

    mov rcx, MeasureMin
    mov rdx, MeasureMax
    cmp rcx, rax
    cmova rcx, rax
    cmp rdx, rax
    cmovb rdx, rax

    add MeasureAvg, rax
    mov MeasureMin, rcx
    mov MeasureMax, rdx

    sub MeasureRetryCountdown, 1
    jae MeasureRetryLoop

    IFNB <Avg>
        mov rax, MeasureAvg
        mov rdx, MeasureRetryAmount

        cvtsi2sd xmm0, rax
        cvtsi2sd xmm1, rdx
        divsd xmm0, xmm1
        movq rax, xmm0

        mov Avg, rax
    ENDIF
    IFNB <Min>
        IFIDN <Min>, <rax>
            mov rax, MeasureMin
        ELSE
            mov [rsp - 8], rax
            mov rax, MeasureMin
            mov Min, rax
            mov rax, [rsp - 8]
        ENDIF
    ENDIF
    IFNB <Max>
        IFIDN <Max>, <rax>
            mov rax, MeasureMax
        ELSE
            mov [rsp - 8], rax
            mov rax, MeasureMax
            mov Max, rax
            mov rax, [rsp - 8]
        ENDIF
    ENDIF
    IFNB <Err>
        IFIDN <Err>, <rax>
            mov rax, MeasureErr
        ELSE
            mov [rsp - 8], rax
            mov rax, MeasureErr
            mov Err, rax
            mov rax, [rsp - 8]
        ENDIF
    ENDIF
ENDM

ENDIF
