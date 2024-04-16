INCLUDE Util/Core.inc

OPTION CASEMAP:NONE
OPTION PROC:PRIVATE

EXTERNDEF __imp_CreateThread: PTR

.CODE
CreateSimpleThread PROC EXPORT
    MaxParam_CreateSimpleThread = 6
    @ProcBegin 8 * MaxParam_CreateSimpleThread

    mov @Param(5, QWORD), 0
    mov @Param(4, DWORD), 0
    mov @Param(3, QWORD), @Arg(1, QWORD)
    mov @Param(2, QWORD), @Arg(0, QWORD)
    mov @Param(1, DWORD), 0
    mov @Param(0, QWORD), 0
    call __imp_CreateThread

    @ProcEnd
CreateSimpleThread ENDP

END
