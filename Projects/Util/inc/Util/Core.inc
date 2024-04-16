IFNDEF UTIL_CORE_INC
UTIL_CORE_INC EQU -1

TRUE            EQU -1
FALSE           EQU 0
CACHE_LINE_SIZE EQU 64

EagerEvalRule TEXTEQU <@DefaultEvalRule>
LazyEvalRule  TEXTEQU <@DefaultEvalRule>

@Assert MACRO Condition:REQ, Message
    IF (Condition) EQ 0
        IFB <Message>
            .ERR <Condition>
        ELSE
            .ERR <Message>
        ENDIF
    ENDIF
ENDM

@ExpandMacro MACRO MacroText:REQ, Args:VARARG
    EXITM MacroText <Args>
ENDM

@HasManyArgs MACRO Args:VARARG
    LOCAL Result, Count

    Result = FALSE
    Count  = 0

    FOR Arg, <Args>
        Count = Count + 1

        IF Count GT 1
            Result = TRUE
            EXITM
        ENDIF
    ENDM

    EXITM %Result
ENDM

@ArgCount MACRO Args:VARARG
    LOCAL Count

    Count = 0

    FOR Arg, <Args>
        Count = Count + 1
    ENDM

    EXITM %Count
ENDM

@ArgReverse MACRO Args:VARARG
    LOCAL Result, ResultSize

    Result TEXTEQU <>

    FOR Arg, <Args>
        Result CATSTR <<Arg>>, <,>, Result
    ENDM

    ResultSize = @SizeStr(%Result)

    IF ResultSize GT 1
        Result SUBSTR Result, 1, ResultSize - 1
    ENDIF

    EXITM Result
ENDM

@GetArg MACRO Index:REQ, Args:VARARG
    LOCAL Result, Count

    Result TEXTEQU <>
    Count = 0

    FOR Arg, <Args>
        IF Count EQ Index
            Result TEXTEQU <Arg>
            EXITM
        ENDIF

        Count = Count + 1
    ENDM

    EXITM Result
ENDM

@SetArg MACRO Index:REQ, Value:REQ, Args:VARARG
    LOCAL Result, Count

    Result TEXTEQU <>
    Count = 0

    FOR Arg, <Args>
        IF Count EQ Index
            Result CATSTR Result, <,>, <<Value>>
        ELSE
            Result CATSTR Result, <,>, <<Arg>>
        ENDIF

        Count = Count + 1
    ENDM

    IF @SizeStr(%Result) GT 1
        Result SUBSTR Result, 2
    ENDIF

    EXITM Result
ENDM

@EagerEval MACRO Expr:REQ, Rule:=<EagerEvalRule>
    LOCAL Result

    Result TEXTEQU <>

    FOR SubExpr, <Expr>
        IF @HasManyArgs(<SubExpr>)
            Result CATSTR Result, <,>, <<@EagerEval(<SubExpr>, <Rule>)>>
        ELSE
            Result CATSTR Result, <,>, <SubExpr>
        ENDIF
    ENDM

    IF @SizeStr(%Result) GT 1
        Result SUBSTR Result, 2
    ENDIF

    IF @HasManyArgs(%Result)
        EXITM @ExpandMacro(<%Rule>, <<%Rule>>, %Result)
    ELSE
        EXITM Result
    ENDIF
ENDM

@LazyEval MACRO Expr:REQ, Rule:=<LazyEvalRule>
    LOCAL Result

    Result TEXTEQU <Expr>

    WHILE TRUE
        IF @HasManyArgs(%Result)
            Result TEXTEQU @ExpandMacro(<%Rule>, <<%Rule>>, %Result)
        ELSE
            EXITM
        ENDIF
    ENDM

    EXITM Result
ENDM

@DefaultEvalRule MACRO Rule:REQ, Arg0, Arg1, Arg2
    LOCAL ArgVal0, ArgVal1, ArgVal2

    ArgVal0 TEXTEQU @EagerEval(<Arg0>, <Rule>)

    IFIDN ArgVal0, <Reg>
        ArgVal1 TEXTEQU @EagerEval(<Arg1>, <Rule>)
        ArgVal2 TEXTEQU @EagerEval(<Arg2>, <Rule>)

        IF ArgVal2 EQ 8
            EXITM @GetArg(ArgVal1, <al, cl, dl, bl, ah, ch, dh, bh, r8b, r9b, r10b, r11b, r12b, r13b, r14b, r15b>)
        ELSEIF ArgVal2 EQ 16
            EXITM @GetArg(ArgVal1, <ax, cx, dx, bx, sp, bp, si, di, r8w, r9w, r10w, r11w, r12w, r13w, r14w, r15w>)
        ELSEIF ArgVal2 EQ 32
            EXITM @GetArg(ArgVal1, <eax, ecx, edx, ebx, esp, ebp, esi, edi, r8d, r9d, r10d, r11d, r12d, r13d, r14d, r15d>)
        ELSEIF ArgVal2 EQ 64
            EXITM @GetArg(ArgVal1, <rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, r8, r9, r10, r11, r12, r13, r14, r15>)
        ELSEIF ArgVal2 EQ 128
            EXITM @GetArg(ArgVal1, <xmm0, xmm1, xmm2, zmm3, xmm4, xmm5, xmm6, xmm7, xmm8, xmm9, xmm10, zmm11, xmm12, xmm13, xmm14, xmm15>)
        ELSEIF ArgVal2 EQ 256
            EXITM @GetArg(ArgVal1, <ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm6, ymm7, ymm8, ymm9, ymm10, ymm11, ymm12, ymm13, ymm14, ymm15>)
        ELSEIF ArgVal2 EQ 512
            EXITM @GetArg(ArgVal1, <zmm0, zmm1, zmm2, zmm3, zmm4, zmm5, zmm6, zmm7, zmm8, zmm9, zmm10, zmm11, zmm12, zmm13, zmm14, zmm15>)
        ENDIF
    ELSEIFIDN ArgVal0, <RegSize>
        ArgVal1 TEXTEQU @EagerEval(<Arg1>, <Rule>)

        IF (OPATTR(ArgVal1)) AND 1
            EXITM %64
        ELSEIF TYPE(ArgVal1) EQ 0
            EXITM %32
        ELSE
            EXITM %TYPE(ArgVal1) * 8
        ENDIF
    ENDIF
ENDM

@Param MACRO Index:REQ, Type:REQ
    IF Index GT 3
        EXITM <(Type PTR [rsp + Index * 8])>
    ELSEIF Index GT 1
        EXITM @EagerEval(<Reg, (Index) + 6, <RegSize, (Type)>>)
    ELSE
        EXITM @EagerEval(<Reg, (Index) + 1, <RegSize, (Type)>>)
    ENDIF
ENDM

@Arg MACRO Index:REQ, Type:REQ, FromStack:=<FALSE>
    IF FromStack OR Index GT 3
        EXITM <(Type PTR [rsp + StackSize + 8 + Index * 8])>
    ELSEIF Index GT 1
        EXITM @EagerEval(<Reg, (Index) + 6, <RegSize, (Type)>>)
    ELSE
        EXITM @EagerEval(<Reg, (Index) + 1, <RegSize, (Type)>>)
    ENDIF
ENDM

@Var MACRO Type:REQ, Name:REQ, Data:REQ
    Name TEXTEQU <(Type PTR Data)>
ENDM

@PushRegs MACRO Regs:VARARG
    FOR Reg, <Regs>
        push Reg
    ENDM
ENDM

@PopRegs MACRO Regs:VARARG
    FOR Reg, <Regs>
        pop Reg
    ENDM
ENDM

@ProcBegin MACRO Size:=<0>, Regs:VARARG
    StackSize = Size
    StackSize = StackSize + (16 - (StackSize + @ArgCount(Regs) * 8 + 8) MOD 16) MOD 16
    SaveRegs  TEXTEQU @ArgReverse(Regs)

    @PushRegs <Regs>

    IF StackSize GT 0
        sub rsp, StackSize
    ENDIF
ENDM

@ProcEnd MACRO
    IF StackSize GT 0
        add rsp, StackSize
    ENDIF

    @PopRegs %SaveRegs

    ret
ENDM

@Call MACRO Func:REQ, Args:VARARG
    LOCAL I

    I = 0

    FOR Arg, <Args>
        mov [rsp - 8], rax

        IF TYPE(Arg) GE 16 AND (NOT OPATTR(Arg)) AND 1
            movq rax, Arg
        ELSE
            mov @EagerEval(<Reg, 0, <RegSize, <Arg>>>), Arg
        ENDIF

        mov [rsp + 8 * I], rax
        mov rax, [rsp - 8]
    
        I = I + 1
    ENDM

IF I GT 0
    mov rcx, [rsp + 8 * 0]
ENDIF
IF I GT 1
    mov rdx, [rsp + 8 * 1]
ENDIF
IF I GT 2
    mov r8,  [rsp + 8 * 2]
ENDIF
IF I GT 3
    mov r9,  [rsp + 8 * 3]
ENDIF
    call Func
ENDM

ENDIF
