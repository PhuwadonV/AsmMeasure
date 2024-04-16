IFNDEF UTIL_MATH_INC
UTIL_MATH_INC EQU -1

@Min MACRO A:REQ, B:REQ
    IF A LE B
        EXITM %A
    ELSE
        EXITM %B
    ENDIF
ENDM

@Max MACRO A:REQ, B:REQ
    IF A GE B
        EXITM %A
    ELSE
        EXITM %B
    ENDIF
ENDM

@Clamp MACRO Min:REQ, Max:REQ, Value:REQ
    IF Value LE Min
        EXITM %Min
    ELSEIF Value GE Max
        EXITM %Max
    ELSE
        EXITM %Value
    ENDIF
ENDM

ENDIF
