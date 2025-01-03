;
; ROMABLE MONITOR 4K IN LENGTH
;
;
; MODIFIED FOR MY IMSAI CP/M INSTALLATION
; BY IMSAIGUY 10/16/83 TO 11/18/83
;
; MODIFIED FOR MY ZETA Z80 (BDOS CALLS FOR I/O)
; ADDED HELP COMMAND
; ADDED ASCII DUMP 11/2017
;
; Modified for TASM assembler 3/12/2019
; Modified for INTEL 80/40-4
;
;
; NOTE - IN GENERAL, ONLY THE FIRST LETTER OF EACH
;        COMMAND WORD NEED BE TYPED.
;

;*********************************************************
;*                                                       *
;*               MEMORY Addressing                       *
;*                                                       *
;*     ROM 0000H - 07FFH                                 *
;*     ROM 0800H - 0FFFH                                 *
;*     ROM 1000H - 17FFH  unused                         *
;*     ROM 1800H - 1FFFH  unused                         *
;*						         *
;*     RAM E000H - F7FFH (6K)                            *
;* ROM/RAM F800H - FFFFH (2K - ISIS Mon ROM or more RAM) *
;*                                                       *
;*********************************************************
;*********************************************************
;*                                                       *
;*               SYSTEM MEMORY PARAMETERS                *
;*                                                       *
;*********************************************************
;
CORE    .EQU     0F7FFH          ;TOP OF UTILITY RAM
ROM     .EQU     0000H           ;START OF ROM
;
PCLOC   .EQU     CORE-2          ;
STACK   .EQU     CORE-28         ;(CORE-1CH) STACK LOCATION
RAM     .EQU     STACK-256D      ;REQUIRES 256 BYTES OF RAM

BASROM  .EQU     02000H          ;ADDRESS OF BASIC ROM
FTHROM  .EQU     04000H          ;ADDRESS OF FORTH ROM
ISROM   .EQU     06000H          ;ADDRESS OF ISIS ROM
BOTRAM  .EQU     0E000H          ;BOTTOM OF RAM
;
;*********************************************************
;*                                                       *
;*               GLOBAL CONSTANTS                        *
;*                                                       *
;*********************************************************
;
CR      .EQU      0DH            ;CARRIAGE RETURN
LF      .EQU      0AH            ;LINE FEED
COMMA   .EQU      2CH            ;COMMA
CTRLC   .EQU      3              ;CONTROL C ABORT
CTRLH   .EQU      8              ;VIDEO TERMINAL BACKSPACE
CTRLO   .EQU      15             ;CONTROL O SUPPRESS OUTPUT
CTRLQ   .EQU      17             ;CONTINUE OUTPUT COMMAND
CTRLS   .EQU      19             ;STOP OUTPUT COMMAND
CTRLZ   .EQU      26             ;END OF ASCII CHAR. IN 'ASC' PSUEDO OP
;
;
; BREAKPOINT RESTART...
;
RS1     .EQU     028H            ;RESTART 5 (RST 7 USED FOR INTERUPTS)
;
;*********************************************************
;*                                                       *
;*               I/O PARAMETERS                          *
;*                                                       *
;*********************************************************
;       8253 TIMER PORTS
CTR0    .EQU		0DCH		;COUNTER #0
CTR1	.EQU		0DDH 		;COUNTER #1 
CTR2	.EQU		0DEH 		;COUNTER #2
TMCP 	.EQU 		0DFH		;COMMAND FOR INTERVAL TIMER 

B9600	 .EQU		07 			;COUNT FOR 9600 BAUD TIMER (9600 x 16 = 153,600)
C2M3	 .EQU		0B6H 		;counter 2 mode three (square wave)

;       8251 UART PORTS
CNCTL	.EQU		0EDH 		;CONSOLE USART CONTROL PORT 
CONST	.EQU		0EDH 		;CONSOLE STATUS INPUT PORT
CNIN	.EQU		0ECH 		;CONSOLE INPUT PORT 
CNOUT	.EQU		0ECH 		;CONSOLE OUTPUT PORT 

TRDY    .EQU        001H        ;Transmit ready
RRDY	.EQU 		002H		;RECEIVER BUFFER STATUS READY
MODE	.EQU 		04EH		;MODE SET FOR USART 1 stop no parity 8 bit 16x clock

CMD		.EQU		036H 		;INITIALIZATION
RESURT 	.EQU 		037H		;RESET ERROR AND SET DTR. 
RSTUST 	.EQU 		040H		;USART MODE RESET COMMAND 

DEBUG   .EQU            0B0H            ;DEBUGGING MULTIMODULE - LEFT DIGIT
DEBUG2  .EQU            0B1H            ;DEBUGGING MULTIMODULE - MIDDLE DIGIT

;*********************************************************
;*                                                       *
;*               EXTERNAL REFERENCES                     *
;*                                                       *
;*********************************************************
;
        .ORG     ROM             ;START OF MONITOR READ-ONLY-MEMORY
;
; ACCOMMODATE NECESSARY RESTART VECTORS AND ADD SOME
; CONVENIENT WORM HOLE VECTORS TO FILL IN.
;
        DI                      ;DISABLE INTERUPTS
        JMP     BEGIN           ;NORMAL ENTRY TO INITIALIZE "EVERYTHING"
        JMP     CHIN            ;
        NOP                     ;FILL
;
        JMP     MSG             ;RST 1
        JMP     TYPE            ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     CRLFMG          ;RST 2
        JMP     SPACE           ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     CRLF            ;RST 3
        JMP     APARAM          ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     GHXB            ;RST 4
        JMP     THXW            ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     RESTART         ;RST 5 ... FOR BREAKPOINT/TRACE
        JMP     GHXW            ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     THXB            ;RST 6
        JMP     GETCH           ;
        NOP                     ;FILL
        NOP                     ;FILL
;
        JMP     ISRVEC          ;RST 7 ... VECTOR TO VECTOR TO ISR
        JMP     CHRSPC          ;
        JMP     POLL            ;
        JMP     HILOW           ;
        JMP     STORE           ;
        JMP     PARAM           ;
        JMP     PU3             ;
        JMP     OKHUH           ;
        JMP     OPMEBY          ;ROUTINE TO OUTPUT MEMORY BYTE
        JMP     PU2             ;
        JMP     HILOEX          ;
        JMP     OUT1            ; output character in A
;
;
;*********************************************************
;*                                                       *
;*               BEGIN MONITOR                           *
;*                                                       *
;*********************************************************
;
; PROGRAM ENTRY POINT...
;
; INITIALIZE EVERYTHING
;
BEGIN:

;debug stuff

;                        MVI     A,01H                   ; PROOF OF LIFE
;                        OUT     DEBUG
;                        MVI     A,02H                   ; QUICK RAM CHECK
;                        STA     0F7FFH
;                        LDA     0F7FFH
;                        OUT     DEBUG

;set up timer for baud rate clock generator

			MVI 	A,C2M3			;INITIALIZE COUNTER #2 FOR BAUD RATE 
			OUT 	TMCP			;OUTPUT COMMAND WORD TO INTERVAL TIMER 
			LXI 	H,B9600			;LOAD BAUD RATE FACTOR 
			MOV 	A,L				;LEAST SIGNIFICANT WORD FOR CTR2 
			OUT 	CTR2			;OUTPUT WORD TO CTR 2 
			MOV 	A,H				;MOST SIGNIFICANT WORD FOR CTR2 
			OUT 	CTR2			;OUTPUT WORD TO CTR2
;set up UART
			MVI	A,00			;USART SET UP MODE 
			OUT	CNCTL			;OUTPUT MODE 
			OUT	CNCTL			;OUTPUT MODE 
			OUT	CNCTL			;OUTPUT MODE 
			MVI	A,040H  		;USART RESET
			OUT	CNCTL			;OUTPUT MODE 
			
			MVI	A,04EH			;USART SET UP MODE. 
			OUT	CNCTL			;OUTPUT MODE 
			MVI 	A,037H			;
			OUT 	CNCTL			;OUTPUT COMMAND WORD TO USART 

;debug stuff after serial port initialized
;                        MVI     A,03H
;                        OUT     DEBUG2
;                        MVI     A,'A'
;                        OUT     CNOUT

;
; LOCATE THE STACK AT THE TOP OF SPECIFIED RAM MEMORY, SET
; THE USER REGISTER SAVE AREA AND EXIT TEMPLATE                                                                                                                                                                                                                                                                                 
;
		LXI     H,CORE-2        ;PLACE DEBUG ENTRANCE AND EXIT TEMPLATE
        MVI     B,ENDX-EXITC    ;IN RAM, B HAS LENGTH OF TEMPLATE
        LXI     D,ENDX          ;POINT TO TEMPLATE END
BG1:    DCX     D               ;MOVE POINTER DOWN
        LDAX    D               ;LOAD A WITH DATA
        DCX     H               ;MOVE MEMORY POINTER DOWN
        MOV     M,A             ;WRITE DATA
        DCR     B               ;END OF TEMPLATE?
        JNZ     BG1             ;LOOP TILL DONE
;
; SET STACK FOR GOTO COMMAND
;
        SPHL
        LXI     H,CORE-63       ;3FH=63D
        PUSH    H
        LXI     H,2
        PUSH    H
        MOV     L,H
        PUSH    H
        PUSH    H
;
; TYPE SIGN-ON MESSAGE
;
        XRA     A               ;ZERO A
        STA     LSTSUPFLAG      ;CLEAR LIST SUPPRESSION FLAG
        LXI     H,M0            ;TYPE ENTRY
        CALL    CRLFMG          ;MESSAGE
        JMP     RESET           ;CONTINUE ELSEWHERE
;
;*********************************************************
;*                                                       *
;*                       NEXT                            *
;*                                                       *
;*               NEXT MONITOR COMMAND                    *
;*                                                       *
;* THIS IS THE RE-ENTRY POINT AFTER EACH COMMAND HAS     *
;* BEEN EXECUTED                                         *
;*                                                       *
;*********************************************************
;
NEXT:   LXI     SP,STACK        ;RESTORE STACK POINTER
        CALL    CRLF            ;TURN UP A NEW LINE
        MVI     A,'-'           ;SEND THE PROMPT
        CALL    TYPE            ;TYPE IT
        MVI     A,'>'           ;GET OTHER HALF
        CALL    CHRSPC          ;TYPE IT AND A SPACE
NXT1:   CALL    CHIN            ;GET COMMAND CHAR
        CALL    TOUPPER
        MOV     B,A             ;AND SAVE COMMAND
        
;
; CHECK FOR SOME LEGAL NON-ALPHA COMMANDS
;
        CPI     '-'             ;EXAMINE PREVIOUS LOCATION
        JZ      LSTLC           ;
        CPI     '.'             ;EXAMINE CURRENT LOCATION
        JZ      LOCAT           ;
        CPI     LF              ;EXAMINE NEXT LOCATION
        JZ      NXLOC           ;
;
; IGNORE NON-ALPHA CHARACTERS
;
        SUI     41H             ;ATLEAST AN 'A'
        JC      NXT1            ;JUMP IF <A
        CPI     1BH             ;AND NOT GREATER THAN 'Z'
        JNC     NXT1            ;JUMP IF >Z
;
; SEARCH OPERATION TABLE FOR COMMAND
;
        LXI     H,OPTAB         ;FETCH TABLE VECTOR
SRCH5:  MOV     A,M             ;GET TABLE COMMAND BYTE
        CPI     0FFH            ;CHECK FOR END OF TABLE
        JZ      ILLEG           ;MUST BE ILLEGAL INPUT
        CMP     B               ;COMPAIR TO INPUT
        JZ      FND5            ;FOUND COMMAND
        INX     H               ;BUMP TO
        INX     H               ;NEXT
        INX     H               ;COMMAND
        INX     H               ; \\
        INX     H               ;   \\
        JMP     SRCH5           ;AND CONTINUE
;
; UNDEFINED COMMAND, TYPE ERROR MESSAGE
;
ILLEG:  LXI     H,M2            ;UNDEFINED
ILLEG1: CALL    MSG             ;MESSAGE
        JMP     RESET           ;CLEAN UP AND TRY AGAIN
;
; FOUND COMMAND, NOW FETCH ADDRESS AND EXECUTE COMMAND
;
FND3:   INX     H               ;BUMP TO LOW ADDRESS BYTE
        MOV     E,M             ;GET ADDR VECTOR
        INX     H
        MOV     D,M
        XCHG                    ;MSG PTR TO HL
        PCHL                    ;GOTO COMMAND PROCESSOR
;
FND5:   INX     H               ;BUMP TO LOW ADDRESS BYTE
        CALL    ILODM           ;GET VECTOR TO BC, MSG TO DE
        XCHG                    ;MSG PTR TO HL
        CALL    MSG             ;SEND THE MESSAGE
        MOV     H,B             ;VECTOR TO HL
        MOV     L,C
        PCHL                    ;GOTO COMMAND PROCESSOR
;
;*************************************************
;*                                               *
;*       OPERATION DECODE/DISPATCH TABLE         *
;*                                               *
;*************************************************
;
OPTAB:  .DB      'A'             ;COMMAND
        .DW      GETAD           ;TO GET ADDRESS
        .DW      M32
;
        .DB      'B'             ;COMMAND
        .DW      BASIC           ;LAUNCH BASIC
        .DW      M72
;
;
        .DB      'D'             ;COMMAND
        .DW      DUMPER          ;TO DUMP MEMORY 
        .DW      M27
;
        .DB      'E'             ;COMMAND
        .DW      DECHO           ;TO DECHO ON IOC
        .DW      M80
;
        .DB      'F'             ;COMMAND
        .DW      FILL            ;TO FILL MEMORY
        .DW      M30
;
        .DB      'G'             ;COMMAND
        .DW      GOTO            ;TO GOTO MEMORY LOCATION (BRKPT OPTION)
        .DW      M28
;
        .DB      'H'             ;COMMAND
        .DW      HELP            ;DISPLAY HELP MESSAGE
        .DW      M70  
;
        .DB      'I'             ;COMMAND
        .DW      PIN             ;INPUT PORT
        .DW      M79
; 
        .DB      'J'             ;COMMAND
        .DW      JUMP            ;TO JUMP TO MEMORY LOCATION
        .DW      M27
;
        .DB      'L'             ;COMMAND
        .DW      LOAD            ;LOAD MEMORY
        .DW      M14
;
        .DB      'M'             ;COMMAND
        .DW      MOVE            ;TO MOVE AREA OF MEMORY
        .DW      M29
;
        .DB      'N'             ;COMMAND
        .DW      BURN1           ;BURN-IN TEST
        .DW      M75
;
        .DB      'O'             ;COMMAND
        .DW      POUT            ;OUT PORT
        .DW      M78
;
        .DB      'P'             ;COMMAND
        .DW      PCMD            ;TO PUNCH INTEL HEX TAPE
        .DW      M51
;
        .DB      'R'             ;COMMAND
        .DW      RCMD            ;TO EXAMINE/MODIFY/DISPLAY REGISTERS
        .DW      M66
;
        .DB      'S'             ;COMMAND
        .DW      ISIS            ;TO EXAMINE/MODIFY/DISPLAY REGISTERS
        .DW      M81       
;
        .DB      'T'             ;COMMAND
        .DW      TEST2           ;TO TEST MEMORY
        .DW      M31
;
        .DB      'U'             ;COMMAND
        .DW      FORTH           ;TO TEST MEMORY
        .DW      M73
;
        .DB      'V'             ;COMMAND
        .DW      VERIFY          ;TO VERIFY BYTE LOCATION
        .DW      M34
;
        .DB      'Z'             ;COMMAND
        .DW      ZAP             ;TO ZAP (ZERO) A BLOCK OF MEMORY
        .DW      M13
; 
        .DB      'X'		 ;COMMAND
	.DW      QUIT            ;EXIT PROGRAM
        .DW      M0
;
        .DB      0FFH            ;END OF TABLE CODE
;
;*************************************************
;*                                               *
;*       SUB OPERATION DECODE/DISPATCH ROUTINES  *
;*                                               *
;*************************************************
;
;
; THE 'D' COMMAND COMES HERE TO READ A SECOND CHARACTER
;
; 'DH' WILL RESULT IN A HEX DUMP
;
;     >< DUMP HEX XXXX YYYY
;
; 'DS' WILL RESULT IN A SYMBOLIC DUMP (DISASSEMBLY IN RADIX SELEC
;     >< DUMP SYMB XXXX YYYY
;
DUMPER: CALL    SPACE           ;SPACE OVER ONE
        LXI     H,DTAB          ;POINT TO DUMP OPTION TABLE
DUMPDA: CALL    CHIN            ;GET SECOND COMMAND CHAR
        CALL    TOUPPER
        MOV     B,A             ;SAVE COMMAND IN B
        JMP     SRCH5           ;SEARCH TABLE FOR COMMAND
;
; DUMP COMMAND DECODE/DISPATCH TABLE
;
DTAB:   .DB      'H'             ;COMMAND TO
        .DW      DUMP            ;DUMP BYTES
        .DW      M35             ;MSG POINTER
        .DB      'S'             ;COMMAND TO
        .DW      DMPSYM          ;DUMP SYMBOLIC
        .DW      M38             ;MSG POINTER
        .DB      0FFH            ;END OF TABLE INDICATOR
;*********************************
;
; THE 'L' COMMAND COMES HERE TO READ A SECOND CHARACTER
;
; INTEL HEX FORMAT LOADER AND A SYMBOLIC LOADER ARE
; AVAILABLE AND ARE SELECTED BY THE CHOICE OF THE SECOND
; COMMAND CHARATER. THE SYMBOLIC LOADER IS A ONE-PASS
; ASSEMBLER WITH A MACRO-COMMAND CAPABILITY.
;
LOAD:   LXI     H,LTAB          ;POINT TO LOADER OPTION TABLE
        JMP     DUMPDA          ;SEARCH TABLE FOR COMMAND
;
; LOADER DECODE/DISPATCH TABLE
;
LTAB:   .DB      'H'             ;COMMAND TO READ
        .DW      HEXIN           ;INTEL HEX FORMAT
        .DW      M35             ;MSG POINTER
        .DB      'S'             ;COMMAND TO
        .DW      LOSYM           ;LOAD SYMBOLIC
        .DW      M38             ;MSG POINTER
        .DB      0FFH            ;END OF TABLE
;*********************************
;
; THE 'P' COMMAND COMES HERE TO READ A SECOND CHARACTER
;
; INTEL HEX FORMAT PUNCHER.
;
; THE SECOND CHARACTER SPECIFIES 'H' FOR HEX, 'E' FOR
; END-OF-FILE, OR 'N' FOR NULLS
;
PCMD:   LXI     H,PTAB          ;POINT TO LOADER OPTION TABLE
        JMP     DUMPDA
;
; PUNCHER DISPATCH TABLE
;
PTAB:   .DB      'H'             ;COMMAND TO PUNCH
        .DW      PUNHEX          ;INTEL HEX FORMAT
        .DW      M35             ;MSG POINTER
        .DB      'E'             ;COMMAND TO PUNCH EOF
        .DW      PEND
        .DW      M67             ;MSG POINTER
        .DB      'N'             ;COMMAND TO PUNCH NULLS
        .DW      NULLS           ;PUNCH COMMAND
        .DW      M64             ;MSG POINTER
        .DB      0FFH            ;END OF TABLE
;*********************************
;
; THE 'R' COMMAND COMES HERE TO READ A SECOND CHARACTER
;
RCMD:   LXI     H,RTAB          ;POINT TO COMMAND TABLE
        JMP     DUMPDA          ;SEARCH TABLE FOR COMMAND
;
; REGISTER COMMAND DECODE/DISPATCH TABLE
;
RTAB:   .DB      'M'             ;EXAMINE/MODIFY
        .DW      MODREG
        .DW      M68+8
        .DB      'E'             ;EXAMINE/MODIFY
        .DW      MODREG
        .DW      M68
        .DB      'D'             ;DISPLAY
        .DW      REGX
        .DW      M69
        .DB      0FFH            ;END OF TABLE
;*********************************
;
; THE 'V' COMMAND COMES HERE TO READ A SECOND CHARACTER
;
; 'VB' WILL RESULT IN A LIST OF THE ADDRESSES OF THE BYTE ZZ
;
;     >< VERIFY HEX XXXX YYYY ZZ
;
; 'VS' WILL RESULT IN A SYMBOLIC LIST (DISASSEMBLY IN RADIX SELEC
;     >< VERIFY SYMB XXXX YYYY ZZ
;
VERIFY: LXI     H,VTAB          ;POINT TO VERIFY OPTION TABLE
        JMP     DUMPDA          ;SEARCH TABLE FOR COMMAND
;
; VERIFY COMMAND DECODE/DISPATCH TABLE
;
VTAB:   .DB      'H'             ;COMMAND TO
        .DW      VERIFB          ;VERIFY BYTES
        .DW      M35             ;MSG POINTER
        .DB      'S'             ;COMMAND TO
        .DW      VERIFS          ;VERIFY SYMBOLIC
        .DW      M38             ;MSG POINTER
        .DB      0FFH            ;END OF TABLE INDICATOR
;
;*********************************************************
;*********************************************************
;**                                                     **
;**              UTILITY SUBROUTINES                    **
;**                                                     **
;*********************************************************
;*********************************************************
;
;*********************************************************
;*                                                       *
;*                        CHIN                           *
;*                                                       *
;*               CHARACTER INPUT ROUTINE                 *
;*                                                       *
;* ROUTINE TO INPUT ONE CARACTER, STRIP OFF PARITY,      *
;* AND ECHO IF ABOVE A SPACE (I.E., NOT CR, LF, ETC.)    *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;* CALL  CHIN  ;CHARACTER IN                             *
;* ...         ;RETURN AFTER ECHO                        *
;*             ;WITH CHAR IN A-REGISTER                  *
;*             ;WITH PARITY STRIPPED OFF                 *
;*                                                       *
;*********************************************************
;
CHIN:   MVI     A,0FFH          ;SET ECHO
        STA     ECHO            ;FLAG ON
CHIN1:  CALL    ASCIN           ;GET CHARACTER & STRIP PARITY
        PUSH    PSW             ;SAVE DATA
        LDA     ECHO            ;AND CHECK
        ANA     A               ; ECHO FLAG
        JNZ     CHIN2           ;ECHO SET
        POP     PSW             ;ECHO NOT SET
        RET                     ; SO RETURN
;
CHIN2:  POP     PSW             ;RESTORE DATA AND ECHO
        CPI     ' '             ;CHECK FOR CONTROL
        CNC     TYPE            ;ECHO IF >= SPACE
        RET                     ;RETURN
;
;*********************************************************
;*                                                       *
;*                       CRLFMG                          *
;*                                                       *
;*********************************************************
;
; SENDS A CARRIAGE RETURN AND LINE FEED THEN THE MESSAGE
; POINTED TO BY HL
;
CRLFMG: CALL    CRLF            ;TURN UP A NEW LINE
;
;*********************************************************
;*                                                       *
;*                        MSG                            *
;*                                                       *
;*   MESSAGE PRINT ROUTINE                               *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*   LXI  H,ADDR  ;ADDRESS OF MESSAGE                    *
;*   CALL MSG     ;CALL ROUTINE                          *
;*   ...          ;RETURN HERE AFTER LAST CHAR           *
;*                ; OF MESSAGE IS PRINTED.               *
;*                                                       *
;* END OF MSG (EOM) CAN BE ANY ONE OF THE FOLLOWING:     *
;*                                                       *
;*   (1) OFFH/377Q                                       *
;*   (2) ZERO                                            *
;*   (3) BIT 8 OF LAST CHAR = 1                          *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
MSG:    PUSH    PSW             ;SAVE PSW
        PUSH    H               ;SAVE HL
MNXT:   MOV     A,M             ;GET A CHARACTER
        CPI     0FFH            ;CHECK FOR 377Q/0FFH/-1 EOM
        JZ      MDONE           ;DONE IF OFFH EOM FOUND
        ORA     A               ;TO CHECK FOR ZERO TERMINATOR
        JZ      MDONE           ;DONE IF ZERO EOM FOUND
        RAL                     ;ROTATE BIT 8 INTO CARRY
        JC      MLAST           ;DONE IF BIT 8 = 1 EOM FOUND
        RAR                     ;RESTORE CHAR
        CALL    TYPE            ;TYPE THE CHARACTER
        INX     H               ;BUMP MEM VECTOR
        JMP     MNXT            ;AND CONTINUE
;
MLAST:  RAR                     ;RESTORE CHARACTER
        ANI     7FH             ;STRIP OFF BIT 8
        CALL    TYPE            ;TYPE THE CHARACTER & EXIT
;
MDONE:  POP     H               ;RESTORE HL
        POP     PSW             ;AND PSW
        RET                     ;EXIT TO CALLER
;
;*********************************************************
;*                                                       *
;*                       CRLF                            *
;*                                                       *
;* ROUTINE TO TURN UP A NEW LINE                         *
;*                                                       *
;* CALLING SEQUENCE ...                                  *
;*                                                       *
;*     CALL  CRLF                                        *
;*     ...           ;RETURN HERE WITH ALL               *
;*                   ;REGISTERS PRESERVED                *
;*                                                       *
;*********************************************************
;
CRLF:   PUSH    PSW             ;SAVE A AND FLAGS
        MVI     A,CR            ;GET A CR
        CALL    TYPE            ;SEND IT
        MVI     A,LF            ;GET A LF
        JMP     SPAC1           ;CONTINUE ELSEWHERE
;
;*********************************************************
;*                                                       *
;*                       CHRSPC                          *
;*                                                       *
;* PRINT CHAR IN 'A' THEN A SPACE CHAR                   *
;*                                                       *
;*********************************************************
;
CHRSPC: CALL    TYPE            ;PRINT CHAR IN 'A'
;
;*********************************************************
;*                                                       *
;*                       SPACE                           *
;*                                                       *
;* ROUTINE TO TYPE ONE SPACE                             *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*     CALL  SPACE                                       *
;*     ...            ;RETURN HERE                       *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
SPACE:  PUSH    PSW             ;SAVE A,PSB
SPAC0:  MVI     A,' '           ;GET A SPACE
SPAC1:  CALL    TYPE            ;AND DO IT
        POP     PSW             ;RESTORE PSW
        RET                     ;AND RETURN
;
;
;*********************************************************
;*                                                       *
;*                        SGHXX                          *
;*                                                       *
;*********************************************************
;
STHXB:  CALL   SPACE            ;TYPE A SPACE
;
;
;*********************************************************
;*                                                       *
;*                       THXB                            *
;*                                                       *
;* ROUTINE TO TYPE VALUE IN 'A' IN HEX ON TTY            *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*    LDA   DATA    ;DATA BYTE IN 'A'                    *
;*    CALL  THXB    ;TYPE IN HEX                         *
;*    ...           ;RETURN HERE                         *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
THXB:   PUSH    PSW             ;SAVE A,PSB
        RRC                     ;SHIFT
        RRC                     ; TO
        RRC                     ;  LEFT
        RRC                     ;   NIBBLE
        CALL    THXN            ;TYPE HEX NIBBLE
        POP     PSW             ;RESTORE DATA
        CALL    THXN            ;TYPE RIGHT NIBBLE
        RET                     ; AND EXIT
;
;*********************************************************
;*                                                       *
;*                       THXN                            *
;*                                                       *
;* ROUTINE TO TYPE ONE ASCII CHARACTER REPRESENTING      *
;* BITS 3-0 FO 'A' IN HEX                                *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*     LDA   DATA   ;DATA NIBBLE IN BITS 3-0             *
;*     CALL  THXN   ;TYPE NIBBLE IN HEX                  *
;*     ...          ;RETURN HERE                         *
;*                                                       *
;* THE CONTENTS OF BITS 4-7 OF THE A-REGISTER ARE NOT    *
;* SIGNIFICANT AND ARE IGNORED.                          *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
THXN:   PUSH    PSW             ;SAVE PSW
        ANI     0FH             ;ISOLATE NIBBLE B3>B0
        CPI     10D             ;SEE IF >9
        JC      $+5             ;NIBBLE <=9
        ADI     7               ;ADJUST ALPHA CHAR
        ADI     '0'             ; ADD IN ASCII 0
        JMP     SPAC1           ;TYPE NIBBLE, POP PSW, RET
;
;
;*********************************************************
;*                                                       *
;*                       STHXW                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO TYPE A SPACE, THEN CONTENTS OF HL IN HEX
;
STHXW:  CALL    SPACE           ;TYPE A SPACE
;
;
;*********************************************************
;*                                                       *
;*                       THXW                            *
;*                                                       *
;* ROUTINE TO TYPE A WORD IN HEX                         *
;*                                                       *
;*   LHLD  WORD    ;WORD IN HL                           *
;*   CALL  THXW    ;TYPE IT IN HEX                       *
;*   ...           ;RETURN HERE                          *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
THXW:   PUSH    PSW             ;SAVE PSW
        MOV     A,H             ;GET HIGH BYTE
        CALL    THXB            ; AND TYPE IT
        MOV     A,L             ;GET LOW BYTE
        CALL    THXB            ; AND TYPE IT
        POP     PSW             ;RESTORE PSW
        RET                     ; AND RETURN
;
;*********************************************************
;*                                                       *
;*                       GHXN                            *
;*                                                       *
;* ROUTINE TO GET ONE HEX CHARACTER FROM TTY             *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*    CALL   GHXN   ;GET HEX NIBBLE                      *
;*    JC     NONHX  ;CARRY SET IF NOW HEX                *
;*    ...           ;HEX NIBBLE IN 'A' B3-B0             *
;*                                                       *
;* IF THE CHARACTER ENTERED IS 0 TO 9 OR A TO F THEN     *
;* 'A' WILL BE SET TO THE BINARY VALUE 0 TO F AND        *
;* THE CARRY WILL BE RESET.                              *
;*                                                       *
;* IF THE CHARACTER IS NOT A VALID HEX DIGIT             *
;* THEN THE 'A' REGISTER WILL CONTAIN THE ASCII CHAR     *
;* AND THE CARRY WILL BE SET TO A 1.                     *
;*                                                       *
;* ALL REGISTERS EXCEPT PSW PRESERVED                    *
;*                                                       *
;*********************************************************
;
GHXN:   CALL    CHIN1           ;GET CHARACTER IN
        CALL    TOUPPER
                                ;(CHIN1 IN CASE NO ECHO)
        CPI     '0'             ;RETURN IF
        RC                      ; < '0'
        CPI     ':'             ;SEE IF NUMERIC
        JC      GHX1            ;CHAR IS 0 TO 9
        CPI     'A'             ;SEE IF A TO F
        RC                      ;CHAR ':' TO '0'
        CPI     'G'             ;SEE IF > 'F'
        CMC                     ;INVERT CARRY SENSE
        RC                      ;CHAR > 'F'
        SUI     7               ;CHAR IS A TO F SO ADJUST
GHX1:   SUI     '0'             ;ADJUST TO BINARY
        RET                     ;AND EXIT
;
;
;*********************************************************
;*                                                       *
;*                       SPCBY                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO TYPE A SPACE THEN GET A HEX BYTE TO 'A'.
; THIS ROUTINE IS DIFFERENT FROM 'GHXB' IN THAT IT WILL
; FORCE A CORRECT BYTE ENTRY.
;
SPCBY:  CALL    SPACE           ;TYPE A SPACE
;
;*********************************************************
;*                                                       *
;*                       INPBY                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO GET A HEX BYTE TO 'A'.
; WILL FORCE A CORRECT ENTRY.
;
INPBY:  CALL    GHXB            ;GET HEX BYTE
        RNC                     ;RETURN IF LEGAL ENTRY
        PUSH    H               ;SAVE HL
        LXI     H,M46           ;SEND THE 'NUM?'
        CALL    MSG             ; MESSAGE
        POP     H               ;RESTORE HL
        JMP     INPBY           ;DO IT AGAIN
;
;
;*********************************************************
;*                                                       *
;*                       SGHXB                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO TYPE A SPACE AND GET A HEX BYTE TO 'A'
;
SGHXB:  CALL    SPACE           ;TYPE A SPACE
;
;
;*********************************************************
;*                                                       *
;*                       GHXB                            *
;*                                                       *
;* ROUTINE TO GET ONE HEX BYTE FROM TTY                  *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*    CALL   GHXB   ;GET HEX BYTE                        *
;*    JC     NONHX  ;SAME AS GHXN, NON-HEX INPUT         *
;*    ...           ;HEX BYTE IN 'A'                     *
;*                                                       *
;* ALL REGS EXCEPT PSW PRESERVED, CARRY SET AS IN GHXN   *
;*                                                       *
;*********************************************************
;
GHXB:   CALL    GHXN            ;GET LEFT NIBBLE
        RC                      ;LEAVE IF NON-HEX
        PUSH    B               ;SAVE BC
        RLC                     ;SHIFT
        RLC                     ; TO
        RLC                     ;  LEFT
        RLC                     ;   NIBBLE
        MOV     B,A             ;AND SAVE IN B
        CALL    GHXN            ;GET RIGHT NIBBLE
        JC      $+4             ;JUMP IF NON-HEX
        ADD     B               ;ADD IN LEFT NIBBLE
        POP     B               ;RESTORE BC
        RET                     ;AND EXIT
;
;
;*********************************************************
;*                                                       *
;*                       PU2                             *
;*                                                       *
;*********************************************************
;
PU2     .EQU     $               ;REPLACES OLD PU2
;
;*********************************************************
;*                                                       *
;*                       SPCWD                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO SEND A SPACE AND FORCE INPUT OF LEGAL HEX
; WORD.  EXITS WITH WORD IN HL PAIR.
;
SPCWD:  CALL    SPACE           ;SEND A SPACE
;
;*********************************************************
;*                                                       *
;*                       INPWD                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO FORCE INPUT OF LEGAL HEX WORD TO HL.
;
INPWD:  CALL    GHXW            ;GET HEX WORD
        RNC                     ;RETURN IF LEGAL
        LXI     H,M46           ;SEND THE 'NUM'
        CALL    MSG             ; MESSAGE
        JMP     INPWD           ;DO IT AGAIN
;
;
;*********************************************************
;*                                                       *
;*                       SGHXW                           *
;*                                                       *
;*********************************************************
;
SGHXW:  CALL    SPACE           ;TYPE A SPACE
;
;*********************************************************
;*                                                       *
;*                       GHXW                            *
;*                                                       *
;* ROUTINE TO GET A HEX WORD FROM TTY                    *
;*                                                       *
;* CALLING SEQUENCE...                                   *
;*                                                       *
;*    CALL   GHXW     ;GET HEX WORD TO HL                *
;*    JC     NONHX    ;NON-HEX IF CARRY SET              *
;*    ...             ;OK, WORD IN HL                    *
;*                                                       *
;* IF INPUT VALUE IS VALID HEX THEN VALUE WILL BE IN HL  *
;*   WITH ALL OTHER REGISTERS PRESERVED AND CARRY RESET. *
;*                                                       *
;* IF INPUT IF INVALID, HL WILL BE PARTIALLY MODIFIED    *
;*   AND CARRY WILL BE SET AND 'A' WILL HAVE THE         *
;*   ILLEGAL NON-HEX CHARACTER                           *
;*                                                       *
;*********************************************************
;
GHXW:   STC             ;SET AND
        CMC             ;CLEAR CARRY
        PUSH    PSW     ;SAVE STATUS
        CALL    GHXB    ;GET HIGH HEX BYTE
        MOV     H,A     ;AND SET TO H
        JNC     GHX2    ;JUMP IF VALID
        POP     PSW     ;RESTORE STATUS
        MOV     A,H     ;SET TO BAD CHARACTER
        STC             ;SET CARRY
        RET             ; AND EXIT
;
GHX2:   CALL    GHXB    ;GET LOW HEX BYTE
        MOV     L,A     ; AND SET TO L
        JNC     GHX3    ;JUMP IF VALID
        POP     PSW     ;INVALID, RESTORE STATUS
        MOV     A,L     ;SET 'A' TO BAD CHAR
        STC             ; SET CARRY
        RET             ;  AND RETURN
;
GHX3:   POP     PSW     ;ALL OK
        RET             ;SO RET WITH HL SET TO WORD
;
;*********************************************************
;*                                                       *
;*                       STORE                           *
;*                                                       *
;* ROUTINE TO STORE A BYTE IN MEMORY WITH READ-BACK CHK  *
;*                                                       *
;* CALLING SEQUENCE ...                                  *
;*                                                       *
;*       ...                     ;ADDRESS IN HL          *
;*       ...                     ;DATA IN 'A'            *
;*       CALL    STORE           ;STORE THE BYTE         *
;*       ...                     ;RETURN HERE IF OK      *
;*                                                       *
;* IF READ-BACK CHECK FAILS, AND APPROPRIATE ERROR       *
;* MESSAGE WILL BE TYPED, AND CONTROL RETURNED TO        *
;* THE USER.                                             *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
STORE:  MOV     M,A             ;STORE THE BYTE
        CMP     M               ;READ-BACK CHECK
        RZ                      ;RETURN IF READ-BACK OK
MEMWE:  PUSH    H               ;ERROR, SAVE VECTOR
        LXI     H,M4            ;TYPE ERROR
        CALL    CRLFMG          ; MESSAGE
        POP     H               ;RESTORE VECTOR
        CALL    THXW            ; AND TYPE ADDRESS
        JMP     NEXT            ;AND RETURN TO EXEC
;
;*********************************************************
;*                                                       *
;*                       LSTOR                           *
;*                                                       *
;*********************************************************
;
; STORES A BYTE IN MEMORY WITH READ-BACK CHECK THEN
; BLINKS FROM PANEL LIGHTS WITH USP OF ADDRESS
;
LSTOR:  CALL    STORE           ;STORE WITH READ-BACK CHK
;
;*********************************************************
;*                                                       *
;*                       GETAD                           *
;*                                                       *
;*               MEMORY EXAMINE/MODIFY ROUTINES          *
;* THE FOLLOWING ROUTINES HANDLE MEMORY EXAMINES AND     *
;* MODIFIES. THE ADDRESS OF THE MEMORY LOCATION          *
;* CURRENTLY BEING ACCESSED IS IN 'ADR'.                 *
;*                                                       *
;* TO INITIALIZE 'ADR', THE MONITOR COMMAND 'A' IS USED. *
;*                                                       *
;*       >< ADDR 1234                                    *
;*                                                       *
;* WILL SET THE 'ADR' TO THE VALUE 1234 (HEX)            *
;*                                                       *
;* THE ROUTINE WILL THEN RETURN THE CARRIAGE, TYPE THE   *
;* VALUE OF 'ADR' AND IT'S CONTENTS IN HEX, AND WAIT     *
;* FOR ONE OF THE FOLLOWING INPUTS:                      *
;*                                                       *
;* - A VALID HEX BYTE TO REPLACE THE VALUE TYPED IN      *
;*   WHICH CASE THE ROUTINE WILL 'STORE' THE BYTE,       *
;*   INCREMENT 'ADR', AND DO THE NEXT ADDRESS            *
;*                                                       *
;* - A LINE-FEED OR SPACE WILL CAUSE THE NEXT ADDRESS    *
;*   TO BE ACESSED WITH-OUT MODIFYING THE CURRENT ONE    *
;*                                                       *
;* - A CARRIAGE-RETURN WILL RETURN CONTROL TO THE        *
;*   MONITOR.                                            *
;*                                                       *
;* - A MINUS SIGN WILL CAUSE THE 'ADR' TO BE             *
;*   DECREMENTED BY ONE.                                 *
;*                                                       *
;* THE LF AND '-' MAY BE ENTERED AS A MONITOR COMMAND    *
;* ALSO AND WILL PERFORM THE SAME FUNCTION.              *
;*                                                       *
;* IN ADDITION, THE COMMAND '.' FROM THE MONITOR WILL    *
;* CAUSE THE CONTENTS OF THE CURRENT 'ADR' TO BE TYPED   *
;* AS IF THE COMMAND 'A' WITH 'ADR' HAD BEEN ENTERED.    *
;*                                                       *
;*********************************************************
;
GETAD:  CALL    PU2             ;GET ADDRESS
        JNC     GTA1            ;JUMP IF VALID
;
ILLCH:  LXI     H,M3            ;ILLEGAL INPUT
        JMP     ILLEG1          ; MESSAGE AND BACK TO
                                ;   MONITOR.
;
GTA1:   SHLD    ADR             ;SAVE 'ADR'
;
LOCAT:                          ;FROM COMMAND '.' ALSO
        CALL    CRLF            ;TURN UP A NEW LINE
        LHLD    ADR             ;FETCH 'ADR'
        CALL    THXW            ; AND PRINT IT
        CALL    SPACE           ;SPACE
        CALL    OPMEBY          ;GET BYTE & PRINT IN HEX
        CALL    SGHXB           ;SEND SPACE & GET COMMAND OR HEX BYTE
        JC      NONHX           ;NON-HEX INPUT
        CALL    STORE           ;STORE THE NEW VALUE
;
NXLOC:                          ;FROM COMMAND 'LF' ALSO
        LHLD    ADR             ;ACCESS
        INX     H               ; NEXT
        JMP     GTA1            ;AND CONTINUE
;
NONHX:  CPI     CR              ;IF CR
        JZ      NEXT            ; RETURN TO USER
        CPI     LF              ;IF LF
        JZ      NXLOC           ; ACCESS NEXT 'ADR'
        CPI     ' '             ;IF SPACE
        JZ      NXLOC           ; ACCESS NEXT 'ADR'
        CPI     '-'             ;IF - ACCESS LAST
        JNZ     ILLCH           ;NOT CR, LF, OR - SO ILLEGAL
;
LSTLC:                          ;FROM COMMAND '-' ALSO
        LHLD    ADR             ;DECREMENT
        DCX     H               ; 'ADR'
        JMP     GTA1            ;AND CONTINUE
;
;*********************************************************
;*                                                       *
;*                       HILOEX                          *
;*                                                       *
;*       COMPARES HL TO DE AND EXITS IF HL>DE            *
;*                                                       *
;*********************************************************
;
HILOEX: CALL    HILOW
        JC      RESET
        RET
;
;*********************************************************
;*                                                       *
;*                       HILOW                           *
;*                                                       *
;*               COMPAIRE HL TO DE                       *
;*                                                       *
;* IF HL<=DE THEN CARRY=0                                *
;* IF HL>DE  THEN CARRY=1                                *
;* THE ROUTINE ALSO INCREMENTS HL.                       *
;*                                                       *
;*********************************************************
;
HILOW:  PUSH    B               ;SAVE BC
        MOV     B,A             ;SAVE A
        INX     H               ;INCREMENT HL
        MOV     A,H             ;TEST FOR HL=0
        ORA     L               ;IF YES, SET ZERO FLAG
        STC                     ; AND CARRY
        JZ      HILO1           ;  AND GO EXIT
        MOV     A,E             ;ELSE
        SUB     L               ; COMPARE
        MOV     A,D             ;  HL WITH
        SBB     H               ;    DE
HILO1:  MOV     A,B             ;RESTORE A
        POP     B               ;  AND BC
        RET
;
;
;*********************************************************
;*                                                       *
;*                       APARAM                          *
;*                                                       *
;*********************************************************
;
APARAM: XRA     A               ;ENTER HERE FOR HL=BEG, DE=END
;
;
;*********************************************************
;*                                                       *
;*                       PARAM                           *
;*                                                       *
;* THIS ROUTINE GETS BEGINNING AND ENDING ADDRESSED FOR  *
;* VARIOUS UTILITY ROUTINES.                             *
;*                                                       *
;* CALLING SEQUENCE ...                                  *
;*                                                       *
;*       ...             ;VALUE IN A                     *
;*       CALL    PARAM   ;GET PARAMETERS                 *
;*       ...             ;RETURN HERE WITH HL & DE       *
;*                       ;CONTAINING ADDRESSES AS        *
;*                       ;FOLLOWS:                       *
;*                                                       *
;* DEPENDING UPON CONTENTS OF THE A REGISTER UPON ENTRY: *
;*                                                       *
;* A = 00  ...  EXITS WITH HL=BEG  DE=END                *
;* A = 01  ...  EXITS WITH HL=BEG  DE=BLOCK SIZE         *
;*                                                       *
;*********************************************************
;
PARAM:  PUSH    PSW             ;SAVE OPTION
        CALL    PU3             ;GET BEG. ADDR TO DE
        CALL    PU3             ;HL=BEG, DE=END
        POP     PSW             ;RESTORE OPTION & SET FLAGS
        ORA     A               ;TO SET FLAGS
        RZ                      ; RETURN IF A=0
;
; A=01 ... EXITS WITH START ADDR IN HL AND BLOCK SIZE IN DE.
; EXITS TO MONITOR IF START ADDR > END ADDR
;
PARAM1: XCHG                    ;HL=END, DE=BEG.
        PUSH    D               ;BEG. ADDR TO STACK
        MOV     A,L             ;LSB OF END ADDR TO A
        SUB     E               ;SUBTRACT LSB OF START ADDR
        MOV     E,A             ;PUT LSB DIFFERENCE IN E
        MOV     A,H             ;MSB OF END ADDR TO A
        SBB     D               ;SUBTRACT W/BORROW MSB OF START ADDR
        MOV     D,A             ;PUT MSB OF DIFF IN D
        POP     H               ;GET START ADRS AGAIN
        JC      ILLEG           ;IF END ADR.LT.BEGIN QUIT
        INX     D               ;ADD ONE TO CORRECT COUNT
        RET                     ;RETURN .. HL=START, DE=SIZE
;
;
;*********************************************************
;*                                                       *
;*                       PU3                             *
;*                                                       *
;* SENDS A SPACE THEN ACCEPTS A HEX ADDRESS. THE ADDRESS *
;* IS CHECKED FOR ILLEGAL HEX CHARACTERS AND IS RETURNED *
;* IN THE DE REGISTER PAIR. PREVIOUS CONTENTS OF DE ARE  *
;* RETURNED IN HL.                                       *
;*                                                       *
;*********************************************************
;
PU3:    CALL    SPCWD           ;SEND A SPACE & GET HEX WORD
        XCHG                    ;PUT IN DE
        RET
;
;*********************************************************
;*                                                       *
;*                       ILODM                           *
;*                                                       *
;* THIS ROUTINE IS USED TO LOAD FOUR CHARACTERS FROM     *
;* MEMORY INTO REGISTERS.                                *
;*                                                       *
;*********************************************************
;
ILODM:  MOV     C,M             ;FETCH CHARACTER TO C
        INX     H               ;
        MOV     B,M             ;FETCH CHARACTER TO B
        INX     H               ;
        MOV     E,M             ;FETCH CHARACTER TO E
        INX     H               ;
        MOV     D,M             ;FETCH CHARACTER TO D
        RET
;
;*********************************************************
;*                                                       *
;*                       OKHUH                           *
;*                                                       *
;*       OK? (OKHUH) - ROUTINE TO VERIFY OPERATION       *
;*                                                       *
;* CALLING SEQUENCE ...                                  *
;*                                                       *
;*       CALL    OKHUH           ;VERIFY                 *
;*       ...                     ;RETURN HERE IF 'Y'     *
;*                               ; ABORT IF NOT          *
;*                                                       *
;* ALL REGISTERS PRESERVED                               *
;*                                                       *
;*********************************************************
;
OKHUH:  PUSH    PSW             ;SAVE PSW
        PUSH    H               ; AND HL
        LXI     H,M7            ;ADR OF 'OK?' MSG
        CALL    MSG             ;PRINT IT
        LXI     H,M8            ;POSSIBLE ABORT
        CALL    CHIN            ;GET ANSWER
        CALL    TOUPPER
        CPI     'Y'             ; 'Y' ?
        JNZ     ILLEG1          ;NO, GO ABORT
        POP     H               ;RESTORE HL
        POP     PSW             ; AND PSW
        RET                     ;  AND LEAVE
;
;*********************************************************
;*                                                       *
;*                       DELAY                           *
;*                                                       *
;*********************************************************
;
; DELAY IS A SOFTWARE DELAY ROUTINE. DELAY TIME IS
; CONTROLLED BY THE VALUE IN THE B-C REGISTER PAIR
;
DELAY:  DCR     C               ;DECREMENT INNER LOOP
        PUSH    H               ;PUSH-POP TO
        POP     H               ;  BURN UP TIME
        JNZ     DELAY           ;INNER LOOP RETURN
        DCR     B               ;DECREMENT OUTER LOOP
        JNZ     DELAY           ;OUTER LOOP RETURN
        RET
;
;*********************************************************
;*                                                       *
;*                       OPCOM                           *
;*                                                       *
;*********************************************************
;
; ROUTINE TO OUTPUT A COMMA
;
OPCOM:  PUSH    PSW
        MVI     A,COMMA
        JMP     SPAC1
;
;
;*********************************************************
;*                                                       *
;*                       OPMEBY                          *
;*                                                       *
;*********************************************************
;
; OUTPUT MEMORY BYTE ADDRESSED BY HL
;
OPMEBY: MOV     A,M             ;GET MEM BYTE
        JMP     THXB            ;TYPE HEX BYTE & RETURN
;
;
;*********************************************************
;*                                                       *
;*                       PCHK                            *
;*                                                       *
;*********************************************************
;
; INPUT CHAR FROM TERMINAL AND CHECK FOR SPACE, "," OR <CR>
; ENTERED. CARRY=1 IMPLIES <CR> ENTERED. ZERO SET IF
; SPACE OR COMMA ENTERED. NOT ZERO IF NONE OF THE THREE
; LEGAL DELIMITERS WERE ENTERED.
;
PCHK:   CALL    CHIN            ;GET A CHARACTER
P2C:    CPI     ' '             ;SPACE?
        RZ                      ;RETURN IF SO
        CPI     ','             ;A COMMA?
        RZ                      ;RETURN IF SO
        CPI     CR              ;A CR?
        STC                     ;SET CARRY
        RZ                      ;RETURN IF CR
        CMC                     ;CLEAR CARRY IF NOT CR
        RET                     ;RETURN NON ZERO IF INVALID
;
;
;*********************************************************
;*                                                       *
;*                       PSLASH                          *
;*                                                       *
;*********************************************************
;
; PRINT A SLASH CHARACTER.
;
PSLASH: PUSH    PSW             ;
        MVI     A,'/'           ;LOAD A SLASH
        JMP     SPAC1           ;CONT ELSEWHERE
;
;*********************************************************
;*                                                       *
;*                       PEQU                            *
;*                                                       *
;*********************************************************
;
; PRINT EQUALS SIGN.
;
PEQU:   PUSH    PSW
        MVI     A,'='
        JMP     SPAC1           ;CONT ELSEWHERE
;

;*********************************************************
;*                                                       *
;*                       DUMP                            *
;*                                                       *
;*       ROUTINE TO DUMP A BLOCK OF MEMORY TO TTY        *
;*                                                       *
;*                                                       *
;* THIS ROUTINE WILL DUMP A BLOCK OF MEMORY ON THE TTY   *
;* 16 BYTES PER LINE WITH THE ADDRESS AT THE START OF    *
;* EACH LINE.                                            *
;*                                                       *
;* THE FOLLOWING MONITOR COMMAND IS USED:                *
;*                                                       *
;*       >< DUMP HEX XXX YYYY                            *
;*                                                       *
;* WILL CAUSE THE CONTENTS OF MEMORY LOCATIONS           *
;* XXXX TO YYYY TO BE PRINTED. XXXX AND YYYY MUST        *
;* BOTH BE VALID FOUR DIGIT HEX ADDRESSES AND IF         *
;* XXXX >= YYYY ONLY LOCATION XXXX WILL BE PRINTED.      *
;*                                                       *
;* AFTER THE FIRST LINE, ALL LINES WILL START WITH AN    *
;* ADDRESS THAT IS A EVEN MULTIPLE OF 16.                *
;*                                                       *
;*********************************************************
;
DUMP:   CALL    APARAM          ;GET PARAMETERS
DMRET:  CALL    CRLF            ;TURN UP A NEW LINE
        CALL    THXW            ;TYPE VECTOR ADDRESS
        CALL    SPACE           ;SPACE
        PUSH    H               ;KEEP FOR ASCII DUMP PART
DMNXT:  CALL    SPACE           ;
        CALL    OPMEBY          ;GET DATA AND DISPLAY
        CALL    HILOEX          ;CHECK FOR ALL DONE, H=H+1
        MOV     A,L             ;CHECK FOR MOD 16
        ANI     15D             ; ADDRESS
        JZ      DMASC           ;CONTINUE WITH ASCII DUMP
        JMP     DMNXT           ; CONTINUE IF NOT
;
; ADD ASCII PART AFTER HEX
; 16 BYTES HEX FOLLOWED BY 16 CHARACTERS ASCII
;
DMASC:  CALL    SPACE           ;SPACE
        CALL    SPACE
        POP     H				;GET MEM LOCATION
DMASC1: MOV     A,M             ;GET BYTE
        CPI     '~'             ;IF > '~' = '.'
        JNC     DMASC3          
        CPI     ' '             ;IF < ' ' = '.'
        JNC     DMASC2
DMASC3: MVI     A,'.'           ;NON PRINTABLE ASCII SET '.'
DMASC2: CALL    TYPE            ;TYPE ASCII
        CALL    HILOEX          ;CHECK FOR ALL DONE, H=H+1
        MOV     A,L             ;CHECK FOR MOD 16
        ANI     15D             ; ADDRESS
        JZ      DMRET           ;DONE, NEW LINE
        JMP     DMASC1          ; CONTINUE IF NOT
;
;*********************************************************
;*                                                       *
;*                       JUMP                            *
;*                                                       *
;*       COMMAND 'J' - DIRECT JUMP TO ADDRESS            *
;*                                                       *
;* THE FOLLOWING MONITOR COMMAND IS USED:                *
;*                                                       *
;*       >< JUMP XXXX                                    *
;*                                                       *
;* WILL CAUSE THE PROCESSOR TO BEGIN PROGRAM EXECUTION   *
;* AT ADDRESS XXXX.                                      *
;*                                                       *
;*********************************************************
;
JUMP:   CALL    PU2             ;GET HEX ADDRESS
        PCHL                    ;THEN JUMP TO IT
;
;*********************************************************
;*                                                       *
;* COMMAND 'M' - MOVE MEMORY BLOCK                       *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< MOVE XXXX YYYY ZZZZ   OK?                    *
;*                                                       *
;* WILL MOVE THE BLOCK OF MEMORY STARTING AT             *
;* XXXX AND ENDING AT AND INCLUDING YYYY TO THE          *
;* BLOCK STARTING AT ZZZZ.                               *
;*                                                       *
;*                                                       *
;* ****;* THE FOLLOWING RESTRICTIONS APPLY! ****;*         *
;*                                                       *
;*  EITHER       ZZZZ <= XXXX                            *
;*                                                       *
;*   OR          ZZZZ > YYYY                             *
;*                                                       *
;* THE ROUTINE MOVES BYTES IN ASCENDING MEMORY ORDER     *
;* SO IF THE HEX ADDRESS VALUES DO NOT SATISFY           *
;* THE ABOVE RULES, MOVED DATA WILL OVERWRITE DATA TO    *
;* BE MOVED.                                             *
;*                                                       *
;*********************************************************
;
MOVE:   CALL    APARAM          ;GET PARAMETERS
        PUSH    H               ;SAVE BEG. ADDR ON STACK
        CALL    PU2             ;GET DEST. ADDR. (ZZZZ)
        XTHL                    ;DE=-YYYY, TOP=ZZZZ, HL=XXXX
        CALL    OKHUH
MOV1:   MOV     A,M             ;GET THRU XXXX
        XTHL                    ;HL=ZZZZ, TOP=XXXX
        CALL    STORE           ;CHECKED STORE
        INX     H               ;BUMP ZZZZ
        XTHL                    ;RESTORE
        CALL    HILOEX          ;CHECK FOR END
        JMP     MOV1            ; AND CONTINUE
;
;*********************************************************
;*                                                       *
;*                       ZAP                             *
;*                                                       *
;* COMMAND 'Z' - ZERO A BLOCK OF MEMORY                  *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< ZAP XXXX YYYY  OK?                           *
;*                                                       *
;* WILL CAUSE MEMORY LOCATIONS XXXX THRU YYYY            *
;* INCLUSIVE TO BE FILLED WITH ZEROS (00 HEX).           *
;*                                                       *
;*********************************************************
;
ZAP:    CALL    APARAM          ;GET PARAMETERS
        XRA     A               ;GET A ZERO
        JMP     FILL0           ;GO FILL WITH ZEROS
;
;*********************************************************
;*                                                       *
;*                       FILL                            *
;*                                                       *
;* COMMAND 'F' - FILL A BLOCK OF MEMORY WITH A VALUE     *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< FILL XXXX YYYY VV  OK?                       *
;*                                                       *
;* WILL CAUSE MEMORY LOCATIONS XXXX THRU YYYY            *
;* INCLUSIVE TO BE SET TO THE VALUE VV (HEX).            *
;*                                                       *
;*********************************************************
;
FILL:   CALL    APARAM          ;GET PARAMETERS
        CALL    SPCBY           ;SEND A SPACE GET VV --> 'A'
FILL0:  CALL    OKHUH           ;SEE IF OK TO PROCEED
FILL1:  CALL    STORE           ;STUFF IT
        CALL    HILOEX          ;SEE IF DONE
        JMP     FILL1           ;  AND CONTINUE
;
;*********************************************************
;*                                                       *
;*               INTEL HEX LOADER/PUNCHER                *
;*                                                       *
;*       ROUTINES TO PUNCH OR LOAD MEMORY ON TTY         *
;*                                                       *
;* THESE ROUTINES WORK WITH DATA IN THE INTEL HEX        *
;* FORMAT. THE FORMAT CONSISTS OF A RECORD READER.       *
;* UP TO 16 BYTES OF DATA, AND A RECORD CHECKSUM.        *
;*                                                       *
;* RECORD FORMAT:                                        *
;*                                                       *
;* HEADER CHARACTER ':'                                  *
;* HEX-ASCII BYTE COUNT, TWO CHARATERS                   *
;* HEX-ASCII LOAD ADDRESS, FOUR CHARACTERS HHLL          *
;* HEX-ASCII RECORD TYPE, TWO CHARATERS 00 FOR DATA      *
;*                                                       *
;* DATA BYTES IN HEX-ASCII, TWO CHARATERS EACH           *
;*                                                       *
;* HEX-ASCII CHECKSUM, TWO CHARACTERS                    *
;*                                                       *
;* THE CHECKSUM IS CALCULATED SUCH THAT THE              *
;* SUM OF ALL THE TWO CHARACTER BYTE FIELDS              *
;* WILL BE ZERO.                                         *
;*                                                       *
;* THE EOF RECORD MAY CONTAIN AN EXECUTION ADDRESS       *
;* IN THE LOAD ADDRESS FIELD.  THE LOAD ROUTINE WILL     *
;* TRANSFER CONTROL TO THIS ADDRESS AFTER READING THE    *
;* TAPE IF THE ADDRESS IS NON-ZERO.                      *
;*                                                       *
;*********************************************************
;*                                                       *
;*               INTEL HEX PUNCHER                       *
;*                                                       *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< PUNCH HEX XXXX YYYY   PAUSE                  *
;*                                                       *
;*********************************************************
;
PUNHEX: CALL    APARAM          ;GET PARAMETERS
        CALL    PWAIT           ;TYPE PROMPT AND WAIT
;
; HL HAS LOW ADDRESS, DE HAS HIGH ADDRESS
;
PN0:    MOV     A,L
        ADI     16D
        MOV     C,A
        MOV     A,H
        ACI     0
        MOV     B,A
        MOV     A,E
        SUB     C
        MOV     C,A
        MOV     A,D             ;
        SBB     B               ;
        JC      PN1             ;RECORD LENGTH = 16
        MVI     A,16D           ;
        JMP     PN2             ;
PN1:    MOV     A,C             ;LAST RECORD
        ADI     17D             ;
PN2:    ORA     A               ;
        JZ      PDONE           ;
        PUSH    D               ;SAVE HIGH
        MOV     E,A             ;E=LENGTH
        MVI     D,0             ;CLEAR CHECKSUM
        CALL    CRLF            ;TURN UP A NEW LINE
        MVI     A,':'           ;PUNCH HDR
        CALL    TYPE            ;
        MOV     A,E             ;
        CALL    PBYTE           ;PUNCH LENGTH
        MOV     A,H             ;PUNCH BLOCK ADDR
        CALL    PBYTE           ;
        MOV     A,L             ;
        CALL    PBYTE           ;
        XRA     A               ;
        CALL    PBYTE           ;PUNCH RECORD TYPE
PN3:    MOV     A,M             ;GET DATA
        INX     H               ;INCREMENT POINTER
        CALL    PBYTE           ;PUNCH DATA
        DCR     E               ;DECR COUNT
        JNZ     PN3             ;CONTINUE
        XRA     A               ;CALCULATE
        SUB     D               ; CHECKSUM
        CALL    PBYTE           ;AND PUNCH IT
        POP     D               ;RESTORE HIGH ADDRESS
        JMP     PN0             ;AND CONTINUE
;
PBYTE:  CALL    THXB            ;
        ADD     D               ;ADD TO SUM
        MOV     D,A             ;
        RET                     ;
;
PDONE:  CALL    CRLF            ;TURN UP A NEW LINE
PDONE1: CALL    GETCH           ;WAIT FOR GO-AHEAD
        JMP     NEXT            ;BACK TO MONITOR
;
; ROUTINE TO TYPE 'PAUSE' MESSAGE
; AND WAIT FOR TTY GO-AHEAD
;
PWAIT:  PUSH    H               ;SAVE H
        LXI     H,M5            ;PROMPT
        CALL    MSG             ; MESSAGE
        POP     H               ;
        CALL    GETCH           ;WAIT FOR GO-AHEAD
        RET                     ;  AND THEN LEAVE
;
;*********************************************************
;*                                                       *
;*               ROUTINE TO PUNCH EOF RECORD             *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< PUNCH EOF XXXX   PAUSE  -OR-                 *
;*       >< PUNCH EOF <CR>   PAUSE                       *
;*                                                       *
;*********************************************************
;
PEND:   CALL    SGHXW           ;TYPE SPACE & GET BIAS OR C/R
        JNC     PEND1           ; ADDRESS
        LXI     H,0             ;SET 0 ADDRESS
        CPI     CR              ;CHECK FOR CR REPLY
        JNZ     ILLCH           ; OTHERS ILLEGAL
PEND1:  CALL    PWAIT           ;PROMPT PAUSE
        CALL    CRLF            ;TURN UP A NEW LINE
        MVI     A,':'
        CALL    TYPE            ;TYPE HDR :
        XRA     A
        MOV     D,A             ;ZERO CHECKSUM
        CALL    PBYTE           ;AND OUTPUT ZERO LENGTH
        MOV     A,H
        CALL    PBYTE           ;EXECUTION
        MOV     A,L
        CALL    PBYTE           ; ADDRESS
        MVI     A,1             ;RECORD TYPE
        CALL    PBYTE
        XRA     A
        SUB     D               ;CALCULATE CHECKSUM
        CALL    PBYTE           ; AND PUNCH IT
        JMP     NULLS1          ;GO SEND TRAILER
;
;*********************************************************
;*                                                       *
;*               ROUTINE TO PUNCH NULLS                  *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< PUNCH NULLS   PAUSE                          *
;*                                                       *
;*********************************************************
;
NULLC:  MVI     C,100D          ;100 NULLS
        XRA     A
NULLC1: CALL    TYPE
        DCR     C
        JNZ     NULLC1          ;CONTINUE
        RET                     ;RETURN
;
;
NULLS:  CALL    PWAIT           ;PROMPT PAUSE
NULLS1: CALL    NULLC           ;GO DO IT
        JMP     PDONE1          ;DONE
;
;*********************************************************
;*                                                       *
;*               INTEL HEX LOADER                        *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< LOAD HEX <CR>                                *
;*       >< LOAD HEX XXXX   (OFFSET=XXXX)                *
;*                                                       *
;*********************************************************
;
HEXIN:  CALL    SGHXW           ;TYPE SPACE & GET BIAS OR C/R
        JNC     LDQ             ;BIAS ADDRESS ENTERED
        LXI     H,0             ;BIAS 0
        CPI     CR              ;CHECK FOR CR
        JNZ     ILLCH           ;OTHERS N.G.
LDQ:    PUSH    H               ;SAVE BIAS
        XRA     A               ;KILL
        STA     ECHO            ; TTY0 ECHO
LD0:    POP     H               ;GET BIAS
        PUSH    H               ;AND RESTORE
        CALL    ASCIN           ;GET INPUT
        MVI     C,':'           ;
        SUB     B               ;CHECK FOR RECORD MARK
        JNZ     LD0
        MOV     D,A             ;CLEAR CHECKSUM
        CALL    BYTE            ;GET LENGTH
        JZ      LD2             ;ZERO ALL DONE
        MOV     E,A             ;SAVE LENGTH
        CALL    BYTE            ;GET HIGH ADDRESS
        PUSH    PSW             ; AND SAVE
        CALL    BYTE            ;GET LOW ADDRESS
        POP     B               ;FETCH MSBYTE
        MOV     C,A             ;BC HAS ADDRESS
        PUSH    B               ;SAVE VECTOR
        XTHL                    ; TO HL
        SHLD    BLKAD           ;SAVE BLOCK ADDRESS
        XTHL                    ; IN CASE OF ERROR
        POP     B               ;RESTORE
        DAD     B               ;ADD TO BIAS
        CALL    BYTE            ;GET TYPE
LD1:    CALL    BYTE            ;GET DATA
        CALL    LSTOR           ;AND STORE IT
        INX     H
        DCR     E
        JNZ     LD1             ;CONTINUE
        CALL    BYTE            ;GET CHECKSUM
        JZ      LD0             ;CONTINUE
;
;
; ERROR...
;
; THIS IS AN ERROR EXIT ROUTINE
; CONTROL RETURNED TO THE MONITOR.
;
ERROR:  LXI     H,M6            ;GET THE ERROR MESSAGE ADDR
        CALL    CRLFMG          ;SEND IT
        LHLD    BLKAD           ;GET BLOCK ADDR
        CALL    THXW            ; AND TYPE IT
        JMP     NEXT            ;BACK TO USER
;
;
LD2:    CALL    BYTE            ;GET MSB OF XEQAD
        MOV     H,A
        CALL    BYTE
        MOV     L,A
        ORA     H
        JZ      NEXT            ;MON IF NO XEQAD
        PCHL                    ;GO TO ROUTINE
;
BYTE:   CALL    GHXB            ;GET TWO CHARACTERS
        MOV     C,A             ;SAVE A IN C
        ADD     D               ;ADD CHECKSUM
        MOV     D,A             ;NEW CHECKSUM TO D
        MOV     A,C             ;RESTORE A
        RET                     ;RETURN
;
;
;*********************************************************
;*                                                       *
;*               MEMORY TEST 2                           *
;*                                                       *
;*********************************************************
;
; COMMAND 'T' - ALL BIT PATTERNS MEMORY TEST
;
; THIS TEST IS EXHAUSTIVE, WRITING ALL BIT PATTERN
; COMBINATIONS IN EACH OF THE ADDRESSES.
;
; AN ERROR FREE CHECK OF 4K OF RAM TAKES ABOUT 30 SECONDS.
;
TEST2:  XRA     A               ;WANT HL=BEG, DE=END
        STA     ERRFL           ;ERROR INDICATOR FLAG
        CALL    PARAM           ;GET PARAMETERS
        CALL    OKHUH           ;GET THE GO AHEAD
TEST21: MVI     B,0FFH          ;INIT. TEST PATTERN
TEST22: MOV     M,B             ;WRITE THE PATTERN
        MOV     A,M             ;READ IT BACK
        CMP     B               ;COMPAIR WITH ORIGINAL
        CNZ     TSTERR          ;IF ERROR, GO DISPLAY IT
        ;;;CALL    CHECK           ;SEE IF WE HAVE INTERUPT
        DCR     B               ;DECREMENT PATTERN
        MOV     A,B             ;FOR END OF PATTERN CHECK
        CPI     0FFH            ;THRU THIS LOCATION ?
        JNZ     TEST22          ;LOOP BACK IF NOT DONE
        CALL    HILOW           ;INC HL/SEE IF TEST DONE
        JNC     TEST21          ;BRANCH IF NOT DONE
        JMP     TSTEXT          ;ALL TESTS EXIT HERE
;
;
; MEMORY TEST ERROR SUBROUTINE
;
;  UPON ENTRY:
;
;       HL = ADDR OF ERROR
;        A = READ BYTE
;        B = WRITE BYTE
;
TSTERR: PUSH    B               ;SAVE BC
        MOV     B,A             ;SAVE A
        LDA     ERRFL           ;GET ERROR FLAG
        ORA     A               ;TO SET ZERO FLAG
        MOV     A,B             ;RESTORE A
        POP     B               ;  AND BC
        JNZ     TE1             ;DON'T HALT IF <> 1ST ERROR
        PUSH    PSW             ;SAVE A
        MVI     A,1             ;SET ERROR FLAG TO NON-ZERO
        STA     ERRFL           ;
        POP     PSW             ;RESTORE A
        CALL    CRLF            ;TURN UP A NEW LINE
TE1:    PUSH    H               ;SAVE HL
        LXI     H,M9            ;GET MESSAGE ADDR
        CALL    CRLFMG          ;SEND MSG
        POP     H               ;RESTORE HL
        CALL    THXW            ;TYPE ADDR OF BAD CHECK
        CALL    SPACE           ;SPACE OVER ONCE
        PUSH    PSW             ;SAVE BAD READING
        MOV     A,B             ;GET REF BYTE
        CALL    THXB            ;CONVERT TO HEX AND PRINT IT
        CALL    SPACE           ;SPACE AGAIN
        POP     PSW             ;GET BAD READING BACK
        CALL    THXB            ;CONVERT AND PRINT IT
        RET                     ;RETURN
;
;
; ALL MEMORY TEST ROUTINES EXIT HERE. IF NO ERRORS WERE
; DISCOVERED, A 'TEST OK' MESSAGE IS PRINTED.
;
TSTEXT: LDA     ERRFL           ;GET ERROR FLAG
        ORA     A               ;SET ZERO FLAG FOR TESTING
        JNZ     NEXT            ;RETURN IF ERRORS WERE FOUND
        LXI     H,M10           ;GET PERFECT TEST MSG
        CALL    MSG             ;SEND IT
        JMP     NEXT            ;RETURN TO USER

; Burn in test
; runs continuously
BURN1:
BURN2:  XRA     A               ;WANT HL=BEG, DE=END
        STA     ERRFL           ;ERROR INDICATOR FLAG
        CALL    PARAM           ;GET PARAMETERS
        CALL    OKHUH           ;GET THE GO AHEAD
BURN20: PUSH    D
        PUSH    H
BURN21: MVI     B,0FFH          ;INIT. TEST PATTERN
BURN22: MOV     M,B             ;WRITE THE PATTERN
        MOV     A,M             ;READ IT BACK
        CMP     B               ;COMPAIR WITH ORIGINAL
        CNZ     TSTERR          ;IF ERROR, GO DISPLAY IT
        ;;;CALL    CHECK           ;SEE IF WE HAVE INTERUPT
        DCR     B               ;DECREMENT PATTERN
        MOV     A,B             ;FOR END OF PATTERN CHECK
        CPI     0FFH            ;THRU THIS LOCATION ?
        JNZ     BURN22          ;LOOP BACK IF NOT DONE
        CALL    HILOW           ;INC HL/SEE IF TEST DONE
        JNC     BURN21          ;BRANCH IF NOT DONE
        LXI     H,M74           ;TYPE ERROR
        CALL    MSG             ; MESSAGE
        POP     H               ;Restore HL and DE,
        POP     D               ;the start and stop addrs        
        JMP     BURN20          ;Run forever

;
;*********************************************************
;*                                                       *
;*                       LOSYM                           *
;*                                                       *
;*                  (FORMERLY ASYM)                      *
;*                                                       *
;*                                                       *
;* LOADS MEMORY FROM 8080 ASSEMBLY LANGUAGE SYMBOLIC     *
;* INPUTS.                                               *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*       >< LOAD SYMB XXXX                               *
;*                                                       *
;* IN ADDITION TO STANDARD 8080 MNEUMONICS, SEVERAL      *
;* MACRO COMMANDS ARE AVAILABLE WHICH REFERENCE          *
;* MONITOR UTILITY ROUTINES:                             *
;*                                                       *
;* LST - PROVIDES DISASSEMBLY LISTING OF CODE ENTERED    *
;*       SO FAR.                                         *
;*                                                       *
;* RUN - JUMPS TO ENTERED ADDRESS OR LAST 'ORG' IN THIS  *
;*       ASSEMBLY. TYPE SPACE & CR OR ADDR.              *
;*                                                       *
;* BYT - ENTER BYTES MODE                                *
;*                                                       *
;* ORG - NEW START ADDRESS FOR ASSEMBLER                 *
;*                                                       *
;* ASC - ENTER ASCII MODE (EXIT WITH ^Z)                 *
;*                                                       *
;* MSG - TYPE OUT MSG AT GIVEN LOCATION                  *
;*       (LXI H,ADR  CALL MSG)                           *
;*                                                       *
;* TTI - CHAR. INPUT                     (CALL ASCIN)    *
;*                                                       *
;* TTE - CHAR. INPUT/ECHO                (CALL CHIN)     *
;*                                                       *
;* TTO - CHAR. OUTPUT                    (CALL TYPE)     *
;*                                                       *
;* BIN - BINARY INPUT                    (CALL GETCH)    *
;*                                                       *
;* LBY - LIST HEX BYTE                   (CALL LSTBY)    *
;*                                                       *
;* LWD - LIST HEX WORD                   (CALL THXW)     *
;*                                                       *
;* IPW - INPUT HEX WORD                  (CALL GHXW)     *
;*                                                       *
;* NWL - NEW LINE MACRO                  (CALL CRLF)     *
;*                                                       *
;* SPC - SPACE MACRO                     (CALL SPACE)    *
;*                                                       *
;* DLY - DELAY MACRO                     (CALL DELAY)    *
;*                                                       *
;*********************************************************
;
LOSYM:  CALL    GHXW            ;GET STARTING ADDR TO HL
        JNC     LOSYM1          ;SKIP DOWN IF ADDR OK
        CPI     CR              ;C/R ENETERED ?
        JZ      AS0             ;YES, OPEN PREVIOUS ADDR
        JMP     ILLCH           ;NO, GRIPE AND EXIT
;
LOSYM1: SHLD    PREADR          ;SAVE START ADDRESS
LOSYM3: SHLD    CLP             ;HL TO CLP
AS0:    XRA     A               ;CLEAR A-REG AND USE
        STA     ADFLAG          ; TO CLEAR ASSEMBLER/DISSASSEMBLER FLAG
        STA     EXFLAG          ;  AND EXCEPTION FLAG
        DCX     H               ;GET RIGHT ADDRESS FOR LISTING
        SHLD    FINCLP          ;SAVE AS FINAL ADDRESS FOR DMPSYM
        INX     H               ;RESTORE H
        CALL    OPCLP           ;O/P CR/LF, CLP, COLON, AND TAB
AS1:    LXI     SP,STACK        ;RESET STACK
        CALL    IPNABT          ;I/P NONBLANK, FIRST LETTER
        JZ      AS1
        CPI     CR              ;EXIT LOSYM COMMAND ?
        JZ      RESET           ;EXIT IF SO
        ANI     3FH             ;MASK
        MOV     C,A             ;STORE IN C
        CALL    IPNABT          ;I/P ALPHABETIC, SECOND LETTER
        JNC     ERR             ;ILLEGAL ENTRY, TYPE ?? AND START OVER
        ANI     3FH             ;ELSE MASK CHARACTER
        MOV     D,A             ;SAVE 2ND CHAR IN D
        CALL    IPNABT          ;I/P THIRD CHARACTER
        JNC     SET2LT          ;JUMP IF ONLY 2 CHARACTERS
        ANI     3FH             ;MASK 3RD CHARACTER
        MOV     E,A             ;SAVE 3RD CHAR IN E
        CALL    IPNABT          ;I/P 4TH CHAR IF THERE IS ONE
        JNC     SETBCT          ;JUMP IF 3 CHARACTERS
        CALL    IPNABT          ;
        JC      ERR             ;
        LXI     H,FOURTBL       ;
        MVI     B,11            ;
SW4LT:  CALL    LOSYMB          ;
        INX     H               ;
        JNZ     SW4LT           ;
ERR:    LXI     H,M3            ;POINT TO ?? MESSAGE
        CALL    CRLFMG          ;SEND THE MESSAGE
        JMP     AS0             ;
;
; CHECK FOR MACRO INSTRUCTION (PSUEDO OPERATION)
;
SETBCT: LXI     H,PSOPR         ;POINT TO THE PSUEDO OP TABLE
        MVI     B,16            ;<<THREETBL-PSOPR>/5> LENGTH OF PSEUDO OPR TABLE/5
TRIMAT: CALL    EXGCMD          ;
        INX     H               ;
        JNZ     TRIMAT          ;
        MVI     B,35H           ;
TMAT2:  CALL    TMAT3           ;
        JNZ     TMAT2           ;
        JMP     ERR             ;
;
SET2LT: LXI     H,TWOTBL        ;
        MVI     B,0FH           ;
        MOV     E,D             ;
        MOV     D,C             ;
TWOMAT: CALL    LET2MA          ;
        JNZ     TWOMAT          ;
        JMP     ERR             ;
;
EXGCMD: CALL    MSKIHL          ;
        MOV     E,M             ;MATCH FOUND, LOAD CMD ADDRESS
        INX     H               ;AND EXECUTE THE COMMAND
        MOV     D,M             ;
        XCHG                    ;
        PCHL                    ;BRANCH TO COMMAND ROUTINE
;
TMAT3:  CALL    MSKIHL          ;
RSTEST: MOV     A,M             ;
        CPI     0FFH            ;
        JNZ     LDCX1           ;
        CALL    INPWD           ;INPUT A HEX WORD
        MOV     A,L             ;
        ORI     0C7H            ;
        MOV     E,A             ;
NODATA: CALL    HLCLP2          ;
        JMP     AS0             ;
;
LET2MA: CALL    GO2LTR          ;
        JMP     LDCX2           ;
;
MSKIHL: CALL    MASK            ;
        CMP     C               ;
        JNZ     LINX            ;
GO2LTR: CALL    MASK            ;
        CMP     D               ;
        JNZ     LINX1           ;
        CALL    MASK            ;
        CMP     E               ;
        JNZ     LINX2           ;
        MOV     E,M             ;
        RET                     ;
;
LINX:   INX     H
LINX1:  INX     H
LINX2:  INX     H
        INX     SP
        INX     SP
        DCR     B
        RET
;
MASK:   MVI     A,3FH
        ANA     M
        INX     H
        RET
;
;
IPNABT: CALL    ASCIN           ;INPUT ASCII CHAR
        CPI     '-'             ;MINUS IS BACK-UP (WAS RUBOUT)
        JNZ     TTYIO0          ;IF SO BACK UP POINTER
        CALL    DECCLP          ;
        JMP     AS0             ;
;
TTYIO0: CPI     LF              ;LINE FEED?
        JZ      IBLS            ;IF SO INCREMENT POINTER
        CALL    TYPE
        CPI     ' '
        PUSH    B
        MOV     B,A
        RLC
        RLC
        MOV     A,B
        POP     B
        RET
;
LOSYMB: CALL    MSKIHL
        INX     H
        MOV     E,M
        DCX     H
LDCX1:  DCX     H
LDCX2:  DCX     H
        DCX     H
        MOV     A,M
        ANI     0C0H
        RLC
        RLC
        INX     H
        JZ      HL2IPB
        DCR     A
        JZ      DSTARG
        DCR     A
        JZ      IPDEST
ONEARG: CALL    MATARG
        ANA     E
        MOV     E,A
        JMP     WAITNA
;
DESUB:  INX     H
        CALL    MATARG
        MOV     B,A
        MOV     A,M
        ANI     40H
        MOV     A,B
        JZ      LRLC
        ORI     1
LRLC:   RLC
        RLC
        RLC
        ANA     E
        MOV     E,A
        DCX     H
        RET
;
IPDEST: CALL    DESUB
SOUARG: CALL    IPNABT
        JC      SOUARG
        JMP     ONEARG
;
DSTARG: CALL    DESUB
WAITNA: CALL    IPNABT
        JC      WAITNA
HL2IPB: MOV     A,M
        ANI     0C0H
        JZ      NODATA
        RLC
        JNC     DAT1BY
        CALL    BY2BUF
        MOV     M,D
        CALL    INCCLP
IBLSBY: MOV     M,C
IBLS:   CALL    INCCLP
        JMP     AS0
;
BY2BUF: CALL    INPWD           ;INPUT A HEX WORD
        MOV     C,H
        MOV     D,L
HLCLP2: LHLD    CLP
        MOV     M,E
        JMP     INCCLP
;
DAT1BY: CALL    INPWD           ;INPUT A HEX WORD
        MOV     C,L
        CALL    HLCLP2
        JMP     IBLSBY
;
MATARG: CALL    IPNABT
        JNC     ERR             ;*****REGISTER ERROR?
        PUSH    B
        LXI     B,REGTBL
        CALL    SWARTA
        INX     B
        LDAX    B
        POP     B
        RET
;
;********************************************************
;*                                                      *
;*                      ASCII                           *
;*                                                      *
;********************************************************
;
; ASCII...
;
; USED IN 'LOSYM' TO LOAD ASCII CHARACTERS WITH THE 'ASC' MACRO
;
; EXIT ASCII MODE WITH A CONTROL-Z (^Z)
;
; PUTS A ZERO AT THE END OF THE MESSAGE ENTERED
;
ASCII:  LHLD    CLP             ;GET CLP
        CALL    CRLF            ;TURN UP A NEW LINE
ASCI1:  CALL    ASCIN           ;GET CHARACTER
        CPI     7FH             ;RUBOUT?
        JZ      ASCI3           ;BACK UP IF SO
        CPI     CTRLZ           ;CONTROL-Z? (ENDS ASCII INPUT)
        JZ      ASCI4           ;
        MOV     M,A             ;STORE ASCII IN MEMORY
        INX     H               ;INCREMENT POINTER
ASCI2:  CALL    TYPE            ;TYPE THE CHARACTER
        JMP     ASCI1           ;NEXT CHARACTER
;
; CTRL-H BACKS UP THE POINTER ON CONRAC UNITS
;
ASCI3:  MVI     A,CTRLH         ;BACK UP THE CURSOR
        CALL    CHRSPC          ; AND SPACE OVER THE CHARACTER THERE
        MVI     A,CTRLH         ;SET UP TO BACK UP AGAIN
        DCX     H               ;BACK UP CLP
        JMP     ASCI2           ;GO BACK UP AND CONTINUE
;
ASCI4:  MVI     M,0             ;STORE A ZERO FOR EOM
ASCI5:  INX     H               ;INCREMENT CLP
ASCI6:  SHLD    CLP             ;STORE CLP
LOSYM0: LHLD    CLP             ;GET CLP
        JMP     LOSYM3          ;BACK TO ASSEMBLER
;
; FOLLOWING ROUTINES ARE USED BY ASSEMBLER MACRO INSTRUCTIONS
;
; THEY REFERENCE UTILITY ROUTINES THRU WORM HOLES TO
; ENSURE OPERABILITY OF THOSE ROUTINES IF MONITOR IS
; RELOCATED.
;
; IF ADDITIONAL MACROS ARE DEFINED, BE SURE TO CHANGE
; THE TABLE LENGTH IN 'SETBCT'.
;
PRTMG:  LHLD    CLP
        MVI     M,21H           ;LXI H, INSTRUCTION
        INX     H
        XCHG                    ;SAVE HL IN DE
        CALL    GHXW            ;GET MESSAGE ADR TO HL
        XCHG                    ;PNTR BACK TO HL, MSG ADDR TO DE
        MOV     M,E             ;
        INX     H
        MOV     M,D             ;MESSAGE ADDRESS LOADED
        INX     H
        LXI     D,MSG           ;GET MESSAGE SUBROUTINE ADR
        SHLD    CLP             ;SAVE PROGRAM ADR IN CLP
LDCALL: LHLD    CLP             ;GET CLP
        MVI     M,0CDH          ;STORE CALL MESSAGE
        INX     H
        MOV     M,E
        INX     H
        MOV     M,D             ;MESSAGE ADDR SAVED
        JMP     ASCI5
;
MTTO:   LXI     D,TYPE          ;LOAD CONSOLE OUTPUT CALL
        JMP     LDCALL
;
MTTI:   LXI     D,ASCIN         ;LOAD CALL TERMINAL INPUT MACRO
        JMP     LDCALL
;
MTTE:   LXI     D,CHIN          ;LOAD CALL TERMINAL INPUT/ECHO MACRO
        JMP     LDCALL
;
MBIN:   LXI     D,GETCH         ;LOAD CALL TERMINAL INPUT MACRO
        JMP     LDCALL
;
MLBY:   LXI     D,THXB          ;LOAD LIST BYTE CALL
        JMP     LDCALL
;
MLWD:   LXI     D,THXW          ;LOAD LIST WORD CALL
        JMP     LDCALL
;
MIPW:   LXI     D,GHXW          ;LOAD INPUT WORD CALL
        JMP     LDCALL
;
MNWL:   LXI     D,CRLF          ;NEW LINE MACRO
        JMP     LDCALL
;
MSPC:   LXI     D,SPACE         ;MACRO PRINT A SPACE CHAR
        JMP     LDCALL
;
MDLY:   LXI     D,DELAY         ;MACRO LONG DELAY
        JMP     LDCALL
;
MRUN:   CALL    GHXW            ;GET ADDR OR CR
        JNC     MRUN1           ;SKIP IF NOT A CR
        CPI     CR              ;CR ENTERED?
        JNZ     ILLEG           ;ILLEGAL IF NOT
        LHLD    PREADR          ;ON CR, GET ADDR OF LAST ORG
MRUN1:  PCHL                    ;EXECUTE THE ADDR
;
;
;*********************************************************
;*                                                       *
;*                       GOTO                            *
;*                                                       *
;* COMMAND 'G' - GO TO MEMORY ADDRESS                    *
;*                                                       *
;* THIS ROUTINE EXPECTS TWO HEX PARAMETERS:              *
;*                                                       *
;*   (ADDRESS) (BREAKPOINT)                              *
;*                                                       *
;* NOTE-  BREAKPOINT IS OPTIONAL. RECOMMEND USE 'JUMP'   *
;*        FOR UNCONDITIONAL BRANCHING HOWEVER.           *
;*                                                       *
;* THE FOLLOWING MONITOR COMMAND IS USED:                *
;*                                                       *
;*       >< GOTO XXXX YYYY                               *
;*                                                       *
;* WILL CAUSE THE PROCESSOR TO BEGIN PROGRAM EXECUTION   *
;* AT ADDRESS XXXX, WITH BREAKPOINT SET AT YYYY.         *
;*                                                       *
;* TWO ADDITIONAL COMMANDS ARE AVAILABLE:                *
;*                                                       *
;*       >< GOTO STEP    - WILL GO STEP TRACE ON INST.   *
;*                         AT ADDRESS IN 'P', THE PROG.  *
;*                         COUNTER. (WHERE BP REACHED,   *
;*                         OR AS SET BY REGS EXAM/MOD)   *
;*                                                       *
;*       >< GOTO TRACE   - BEGINS CONTINUOUS TRACE AT 'P'*
;*                                                       *
;*********************************************************
;
; CLP = CURRENT LOCATION POINTER
;
GOTO:   LXI     H,0             ;CLEAR FINAL ADDRESS FOR DMPSYM
        SHLD    FINCLP          ;STORE FINAL CLP
        CALL    GHXW            ;GET GOTO ADDR OR SECOND CHAR.
        JNC     GOT1            ;SKIP DOWN IF VALID ADDR
        CPI     CR              ;WAS IT CR?
        JZ      GO4             ;JUMP IF CR ENTERED
        CPI     ' '             ;SPACE ENTERED?
        JZ      GO0             ;JUMP IF SPACE ENTERED
        CPI     ','             ;COMMA ENTERED?
        JZ      GO0             ;JUMP ON COMMA SEPARATOR ENTERED
        CPI     'S'             ;STEP TRACE REQUEST?
        JZ      TRACE           ;TRACE ONE INSTRUCTION IF SO
        CPI     'T'             ;TRACE CONTINUOUS REQUEST?
        JZ      TRACON          ;GO TRACE CONTINUOUS IF SO
        JMP     ILLEG           ;ILLEGAL ENTRY
;
GOT1:   SHLD    CLP             ;SAVE GOTO ADDRESS IN CLP
        PUSH    PSW             ;SAVE A
        MOV     A,M             ;GET OPCODE (CONTENTS OF DESTINATION ADDR)
        STA     LASTOPC         ;SAVE IT (OPCODE STORAGE LOCATION)
        POP     PSW             ;RESTORE A
        XCHG                    ;CLP --> DE
        LXI     H,PLOC          ;POINT TO GOTO ADDRESS IN ENTRANCE TEMPLATE
        DAD     SP              ;
        MOV     M,D             ;DE HAS CLP
        DCX     H
        MOV     M,E
        CPI     CR              ;????????
        JZ      GO3
GO0:    LXI     H,TLOC
        DAD     SP
GO1:    PUSH    H               ;SAVE HL
        CALL    SGHXW           ;GET BREAKPOINT ADDR OR SECOND CHAR.
        MOV     B,H             ;PUT ADDR
        MOV     C,L             ; INTO BC
        POP     H               ;RESTORE HL
        JNC     GO2             ;SKIP DOWN IF VALID ADDR
        CPI     'S'             ;STEP TRACE REQUEST?
        JZ      TRACE           ;TRACE ONE INSTRUCTION IF SO
        CPI     'T'             ;TRACE CONTINUOUS REQUEST?
        JZ      TRACON          ;GO TRACE CONTINUOUS IF SO
GO2:    CALL    SETBP           ;SET BREAKPOINT AND SAVE DATA
GO3:    CALL    LMNUM           ;LIST THE INSTRUCTION TO BE EXECUTED
        CALL    SPACE           ;PRINT A SPACE
;
; FOLLOWING MUST BE INSERTED IF ASSEMBLED AT OTHER THAN
; ADDRESS ZERO

GO4:    MVI     A,0C3H          ;SET JUMP ADDRESS AT RESTART
        STA     RS1
        LXI     H,RESTART
        SHLD    RS1+1
; GO4:
        LXI     H,8H
        DAD     SP
        PCHL                    ;BRANCH TO ENTRANCE TEMPLATE

HELP:
        LXI     H,M71            ;TYPE ENTRY
        CALL    MSG              ;MESSAGE
        JMP     RESET

; Run BASIC from ROM #1 (02000)

BASIC:
        JMP     BASROM           ; JUMP TO ROM 2

; Run forth from ROM #2 (0x4000)
; We copy forth from ROM at 4000 to RAM at E000 and then run it

FORTH:  LXI     H, FTHROM
        LXI     D, BOTRAM
        LXI     B, 1E80H
CPFTH:  MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCX     B
        MOV     A,B             ; are we done yet?
        ORA     C
        JNZ     CPFTH
        JMP     BOTRAM

; Boot ISIS. There are two ways to do this: 1) ISIS Booter is in
; ROM at E800, and 2) ISIS Booter is in ROM at 6000, and we copy it to RAM
; at E800. It depends on the configuration of the Multibus CPU board, and
; whether we have the MEM-ISIS PLD installed on the ramboard.

ISIS:   MVI     A,01H                   ; Try to write something to E800H
        STA     0E800H
        LDA     0E800H
        CPI     0C3H                    ; Is the ISIS ROM there?
        JNZ     RAMIS                   ; Nope. Proceed with ISIS in RAM
        LXI     H,M83                   ; RUNNING ISIS FROM ROM MESSAGE
        CALL    MSG        
        JMP     0E800H

; Copy ISIS booter from ROM #3 (0x6000) to E800H and run it
; Copy it to E800H
RAMIS:  LXI     H,M82                   ;COPYING ISIS MESSAGE
        CALL    MSG
        LXI     H, ISROM                ; H = src (ISIS ROM)
        LXI     D, 0E800H               ; D = dst (ISIS bootloader address)
        LXI     B, 1800H                ; B = count (length of ISIS ROM)
CPIS:   MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCX     B
        MOV     A,B                     ; are we done yet?
        ORA     C
        JNZ     CPIS
        LXI     H, ROMOFF               ; H = src (romoff)
        LXI     D, 0E000H               ; D = dest (0xE000, good place in RAM)
        LXI     B, (ROMOF1-ROMOFF)      ; B = length of ROMOFF routine
CPRO:   MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCX     B
        MOV     A,B             ; are we done yet?
        ORA     C
        JNZ     CPRO
        JMP     0E000H

; ROMOFF routine, put this in RAM because the ROM disappears part way through
; Disable ROM and JUMP to E800
; Install Jumper E25-E32
; Put E6-5 into output mode
; Set E6-5 to 0
; Jump to E800

ROMOFF: MVI     A,10010011B     ; Mode set, Port C upper is output, all others input
        OUT     0E7H            ; 8255 control port. ROM might go away now; datasheet was unclear.
        MVI     A,00001010B     ; Bit set, Port C-5 to 0
        OUT     0E7H            ; If ROM didn't go away before, it'll go away now.
        JMP     0E800H
ROMOF1:

;
;*********************************************************
;*                                                       *
;*               TRACE CONTINUOUS                        *
;*                                                       *
;*********************************************************
;
TRACON: STA     TRCONFLAG
        LXI     H,M58           ;POINT TO TRACE MESSAGE
        CALL    MSG             ;SEND IT
        JMP     TRACE0          ;CONTINUE ELSEWHERE
;
TRCON1: LDA     LASTOPC         ;GET LAST OP CODE
        CPI     0DBH            ;INPUT INSTRUCTION?
        JNZ     TRCON2          ;NOT INPUT
        LXI     H,CORE-17H      ;FETCH ACCUMULATOR
        MVI     A,'?'           ;PRINT A QUESTION MARK
        CALL    CHRSPC          ;
        CALL    GHXB            ;GET HEX BYTE OR SPACE
        JNC     TRCO11          ;SKIP DOWN IF VALID
        CPI     ' '             ;SPACE?
        JZ      TRCON2          ;IF SO, DON'T MODIFY ACC
TRCO11: MOV     M,A             ;REPLACE A
TRCON2: CALL    DSPREG          ;TRIGGER REGISTER DISPLAY
        LDA     TRCONFLAG       ;FETCH TRACE CONTINUOUS FLAG
        ORA     A               ;TEST IT
        JZ      RESET           ;DON'T CONTINUE IF NOT SET
        JMP     TRACE0          ;CONTINUE TRACE
;
;
TRACE:  LXI     H,M57           ;POINT TO STEP TRACE MSG
        CALL    MSG             ;SEND IT
TRACE0: LXI     H,PLOC          ;GET POINTER TO PC
        DAD     SP              ;
        MOV     D,M             ;GOTO ADDR TO DE
        DCX     H
        MOV     E,M
        XCHG
        SHLD    CLP
        XCHG
        LDAX    D               ;GET INSTRUCTION
        STA     LASTOPC         ;SAVE INSTRUCTION
        ANI     0C7H
        CPI     0C0H            ;CONDITIONAL RETURN?
        JZ      RETBP           ;SET RETURN BREAKPOINT
        LDAX    D               ;GET INSTRUCTION AGAIN
        CPI     0C9H            ;UNCONDITIONAL RETURN?
        JZ      RETBP           ;SET RETURN BREAKPOINT
        CPI     0E9H            ;PCHL?
        JNZ     TRACE1          ;NOT PCHL, OR OTHERS, CONTINUE.
        LXI     H,HLOC          ;GET HL POINTER
        DAD     SP              ;
        MOV     D,M             ;PSEUDO HL TO DE
        DCX     H
        MOV     E,M
        XCHG                    ;PSUEDO HL TO HL
        SHLD    OPCADR          ;SAVE AS SECOND BP ADR
TRACE1: CALL    LMNUM           ;LIST THE OPCODE ABOUT TO BE EXECUTED
        CALL    SPACE           ;PRINT A SPACE
        CALL    INCCLP          ;POINT TO NEXT INSTRUCTION
        MOV     B,H             ;GET FIRST BREAKPOINT ADDRESS LEFT FROM LMNUM
        MOV     C,L             ;AND PUT IN BC
        LXI     H,TLOC          ;FETCH BREAKPOINT ADDRESS STORAGE LOCATION
        DAD     SP
TRACE2: CALL    SETBP           ;SAVE BREAKPOINT AND SET IT
        XCHG                    ;SAVE BREAKPOINT STORAGE LOCATION
        LHLD    OPCADR          ;GET ADDRESS IN ARGUEMENT FIELD OF INSTRUCTION
        MOV     A,L             ;TEST FOR FFFF ADDRESS
        ANA     H
        INR     A               ;A ZEROS IF IT WAS ALL ONES
        JZ      GO4             ;ZERO ADDRESS MEANS ONLY ONE BREAKPOINT
                                ;SO EXIT AND BREAK TO PROGRAM
        MOV     B,H             ;PUT 2ND BP ADR IN BC
        MOV     C,L             ;
        LXI     H,0FFH          ;ALL ONES TO HL
        SHLD    OPCADR          ;CLEAR 2ND BR ADR REGISTER
        XCHG                    ;RESTORE HL
        JMP     TRACE2          ;SET 2ND BREAKPOINT
;
;*********************************************************
;*                                                       *
;*               SET BREAKPOINT                          *
;*                                                       *
;*********************************************************
;
SETBP:  MOV     M,C             ;SAVE BREAKPOINT
        INX     H
        MOV     M,B
        INX     H
        LDAX    B               ;GET INSTRUCTION AT BREAKPOINT
        MOV     M,A             ;SAVE IT ALSO
        INX     H
        MVI     A,0C7H+RS1      ;STORE RESTART INSTRUCTION IN BP ADDRESS
        STAX    B
        RET
;
;*********************************************************
;*                                                       *
;*               RESTORE BREAKPOINT                      *
;*                                                       *
;*********************************************************
;
RETBP:  LXI     H,SLOC          ;GET POINTER TO PSEUDO STACK
        DAD     SP
        MOV     D,M             ;GET PSEUDO STACK POINTER VALUE
        DCX     H               ;
        MOV     E,M
        XCHG                    ;PSEUDO STACK POINTER TO HL
        MOV     E,M             ;GET RETURN ADDRESS
        INX     H
        MOV     D,M             ;
        XCHG                    ;RETURN ADR TO HL
        SHLD    OPCADR          ;SAVE AS SECOND BP
        JMP     TRACE1          ;CONTINUE
;
;*********************************************************
;*                                                       *
;*                       DMPSYM                          *
;*                                                       *
;*               DUMP SYMBOLIC                           *
;*                                                       *
;* DUMP SYMB XXXX YYYY                                   *
;*                                                       *
;*********************************************************
;
; DUMP SYMBOLICALLY THE CONTENTS OF MEMORY COMMAND
;
; (DISASSEMBLES)
;
; CLP = CURRENT POINTER
;
DMPSYM: CALL    GHXW            ;GET STARTING ADDR TO HL
        JNC     DSYM0           ;SKIP DOWN IF ADDR OK
        CPI     CR              ;WAS CR ENTERED
        JZ      DSYM1           ;SEND PREVIOUS DUMP IS SO
        JMP     ILLCH           ;GO GRIPE ABOUT ILLEGAL ADDRESS
;
DSYM0:  SHLD    CLP             ;START ADDRESS TO CLP
        SHLD    PREADR          ;SAVE AS NEW INIT ADDRESS
        CALL    PU2             ;GET ANOTHER ADDRESS
        SHLD    FINCLP          ;STORE FINAL ADDRESS
        JMP     NEXT0           ;BEGIN DUMP
;
DSYM1:  LHLD    PREADR          ;GET PREVIOUS INIT ADDRESS
        SHLD    CLP             ;SAVE INITIAL ADDRESS IN CLP
NEXT0:  CALL    LMNUM
XNEXT:  LXI     SP,STACK        ;RESET STACK IN CASE BYTE WAS FOUND
        CALL    ENDCHK          ;CHECK FOR END OF BLOCK?
        JMP     NEXT0
;
LMNUM:  XRA     A               ;CLEAR EXCEPTION FLAG
        STA     EXFLAG
        MVI     A,'D'           ;SET ASSEMBLER/DISASSEMBLER FLAG
        STA     ADFLAG          ;
        CALL    OPCLP           ;OUTPUT CURRENT ADDRESS
        CALL    RSTST           ;CALL RESTART AND MASK TEST
NEXT1:  CALL    EXCEPT          ;CALL EXCEPTION TEST
        CALL    PTMNEU          ;OUTPUT MNEUMONIC
        CALL    SPACE           ;PRINT A SPACE
        LDA     AUGFLAG         ;ARGUEMENT FLAG TO ACC
        ANA     A               ;TEST ARGUEMENT FLAG
        JZ      SKIPCO          ;NO ARGUEMENT? THEN SKIP COMMA AND ARG PRINT ROUTINE
        CALL    PRTARG          ;ELSE PRINT ARGUEMENT
        LDA     DBFLAG          ;GET DATA BYTES FLAG
        ANA     A               ;TEST DATA BYTES FLAG
        RZ                      ;NO DATA BYTES - GO GET NEXT INSTRUCTION
        CALL    OPCOM           ;ELSE PRINT A COMMA
SKIPCO: LDA     DBFLAG          ;GET DATA BYTES FLAG
        ANA     A               ;TEST DATA BYTES FLAG
        RZ                      ;NO DATA BYTES? GO GET NEXT INSTRUCTION
        CALL    INCCLP          ;INCREMENT CLP AND RETURN NEW CLP TO HL
        DCR     A               ;CHECK FOR ONE OR TWO DATA BYTES
        JZ      OPMEBY          ;DB FLAG = 1 THEREFORE OUTPUT ONE BYTE
                                ;ELSE OUTPUT TWO DB'S
        MOV     E,M             ;MEMORY AT CLP TO E REGISTER
        CALL    INCCLP          ;INCREMENT CLP AND RETURN CLP TO HL
        MOV     D,M             ;MEMORY AT CLP TO D REGISTER
        LXI     H,TABEND        ;POINT TO SHLD,LHLD,STA,LXI,AND LDA TABLE
SKIP1:  INX     H               ;POINT TO INSTRUCTION
        LDA     LASTOPC         ;GET CURRENT OPC
        CMP     M               ;IS IT IN TABLE
        MOV     A,M             ;SAVE BYTE IN TABLE IN 'A'
        XCHG
        JZ      THXW            ;YES, JUST LIST THE WORD, NO BREAKPOINT
        XCHG
        DCR     A               ;SEE IF END OF TABLE, LAST BYTE IS A 1
        JNZ     SKIP1           ;NO, GET NEXT ONE
        XCHG                    ;DE <--> HL
        SHLD    OPCADR          ;SAVE ADDRESS AUG. FOR DEBUG
        JMP     THXW            ;PRINT THE 2 DB'S AS AN ADDRESS & RETURN
;
OPCLP:  LHLD    CLP             ;CLP TO HL
OPADR:  CALL    CRLF            ;TURN UP A NEW LINE
        CALL    THXW            ;PRINT CLP
PCOL:   MVI     A,':'           ; WITH A COLON FOLLOWING
        JMP     CHRSPC          ;TYPE CHAR, SPACE & RETURN
;
RSTST:  MOV     A,M             ;RESTART AND MATCH TEST
        ANI     0C7H
        CPI     0C7H
        JNZ     MATCH
        PUSH    H               ;SAVE HL
        MOV     A,M             ;GET RST INSTRUCTION
        ANI     38H             ;MASK CALL ADDRESS
        MOV     L,A             ;SAVE IN HL
        MVI     H,0
        SHLD    OPCADR          ;SAVE BP2 REGISTER
        POP     H
        LXI     D,TABEND
        MVI     A,3
        STA     MATCHFLAG
        RAR
        STA     AUGFLAG
        RET
;
MATCH:  LXI     D,TWOTBL        ;MATCH TEST
        MVI     A,2
MAT0:   STA     MATCHFLAG
        MOV     B,A
        CALL    ARGTST
        MOV     A,B
        ADD     E
        MOV     E,A
        JNC     MAT1
        INR     D
MAT1:   LDAX    D
        CMP     C
        RZ
        CALL    MAT2
        MOV     A,B
        JMP     MAT0
;
MAT2:   CPI     0F3H
        JZ      SETF24
        CPI     0E9H
        JZ      SETF23
        CPI     0FFH
        JZ      TF24
        CPI     0E3H
        INX     D
        RNZ
PDB:    LDA     ADFLAG          ;GET ASSEMBLER/DISASSEMBLER FLAG
        ORA     A               ;TEST FLAG
        JZ      ERR             ;ITS ASSEMBLER ERROR
        CALL    TYPE            ;ELSE ITS DATA BYTE UNDER DISASSEMBER
        MVI     A,'B'
        CALL    CHRSPC
        LHLD    CLP
        CALL    OPMEBY
        JMP     XNEXT
;
TF24:   INR     B
        LXI     D,FOURTBL
        RET
;
SETF23: DCR     B
        LXI     D,THREETBL
        RET
;
SETF24: INR     B
        INR     B
        LXI     D,FOURT1
        RET
;
ARGTST: LDAX    D               ;ARGUEMENT TEST
        RLC
        RLC
        ANI     3
        STA     AUGFLAG
        JNZ     ARG0
        MOV     C,M
        RET
;
ARG0:   DCR     A
        JNZ     S12ARG
        MOV     A,M
        ORI     38H
        MOV     C,A
        RET
;
S12ARG: DCR     A
        JNZ     OARGS
        MOV     A,M
        ORI     3FH
        MOV     C,A
        RET
;
OARGS:  MOV     A,M
        ORI     7
        MOV     C,A
        RET
;
EXCEPT: ADI     0C5H            ;EXCEPTION TEST
        JZ      NOEXCP
        INR     A
        JZ      NOEXCP
        INR     A
        JNZ     HLTEST
NOEXCP: MOV     A,M
        CPI     3AH
        RZ
        ANI     08H
        RZ
        MVI     A,0F7H
        STA     EXFLAG
NOEX1:  LDA     MATCHFLAG
        ADD     E
        MOV     E,A
        JNC     NOEX2
        INR     D
NOEX2:  INX     D
        RET
;
HLTEST: MOV     A,M             ;GET CHARACTER
        CPI     76H             ;HLT INSTRUCTION?
        RNZ                     ;RETURN IF NOT
        SUB     A
        STA     AUGFLAG
        JMP     NOEX1
;
PTMNEU: CALL    GOTO1L
        LDA     MATCHFLAG
        MOV     C,A
        CALL    PRINT
        INX     D
        DCR     C
        LDAX    D
        ANI     0C0H
        RLC
        RLC
        STA     DBFLAG
        CALL    PRINT
PTM0:   DCR     C
        RZ
        INX     D
        CALL    PRINT
        JMP     PTM0
;
GOTO1L: LDA     MATCHFLAG
G0:     DCX     D
        DCR     A
        JNZ     G0
        RET
;
PRINT:  LDAX    D
        ANI     3FH
        ORI     40H
OPCALL: CALL    TYPE
        DCR     B
        RET
;
PRTARG: DCR     A               ;PRINT ARGUEMENT SUBROUTINE
        JZ      DE1ARG
        DCR     A
        JZ      PT2ARG
PRTAR1: MOV     A,M
        ORI     0F8H
PRTAR2: PUSH    B
        LXI     B,REGTBL+1
        CALL    SWARTA
        DCX     B
        LDAX    B
        POP     B
        JMP     OPCALL
;
DE1ARG: MOV     A,M
        ANI     0C7H
        CPI     0C7H
        JNZ     SPTEST
        MOV     A,M
        ANI     38H
        JMP     THXB
;
PT2ARG: CALL    SPTEST
        CALL    OPCOM
        DCR     B
        JMP     PRTAR1
;
SWARTA: PUSH    D
        MVI     E,0AH
        MOV     D,A
CMPBYS: LDAX    B
        CMP     D
        JNZ     LDCRE
        POP     D
        RET
;
PRTSP:  LXI     H,M25           ;POINT TO 'SP' MSG
        JMP     MSG             ;PRINT IT & RETURN
;
SPTEST: MOV     A,M
        ANI     0F5H
        CPI     31H
        JZ      PRTSP
        ANI     0F1H
        CPI     0F1H
        JNZ     SPT1
PRTPSW: LXI     H,PSWMG
        JMP     MSG
;
SPT1:   MOV     C,M
        LDA     EXFLAG
        CPI     0F7H
        JNZ     GENARG
        ANA     C
        MOV     C,A
GENARG: MVI     A,38H
        ANA     C
        RRC
        RRC
        RRC
        ORI     0F8H
        JMP     PRTAR2
;
LDCRE:  DCR     E
        JZ      PDB
        INX     B
        INX     B
        JMP     CMPBYS
;
ENDCHK: LHLD    FINCLP
        XCHG
        LHLD    CLP
        CALL    HILOW
        SHLD    CLP

        JC      RESET
        RET
;
INCCLP: LHLD    CLP
INHLSP: INX     H               ;INCREMENT HL AND SAVE IN CLP
INC0:   SHLD    CLP
        RET
;
DECCLP: LHLD    CLP
        DCX     H
        JMP     INC0
;
;
; 'BYT' IS A MACRO COMMAND USED BY LODSYM
;
BYT:    CALL    INCCLP          ;GET CLP, INCREMENT IT AND RESAVE
BYT1:   DCX     H
        CALL    OPADR
        CALL    OPMEBY
        CALL    PSLASH
        CALL    ASCIN           ;INPUT ASCII
        CPI     '-'             ;BACK UP POINTER ? (WAS RUBOUT)
        JZ      BYT1            ;IF SO BACK UP POINTER
        CPI     LF              ;LINE FEED?
        JZ      BYT2            ;IF SO ADVANCE POINTER
        CALL    P2C             ;CHECK DELIMITER
        JC      ASCI6           ;EXITED TO RESET BEFORE
        JZ      BYT2
        CALL    TYPE
        CALL    GHXB            ;GET HEX BYTE
        MOV     M,A             ;STORE IT
;
; DO WE NEED JC EXIT FOR NON-HEX BYTE???
;
        CPI     CR
        JZ      ASCI6           ;EXITED TO RESET BEFORE
BYT2:   INX     H
        SHLD    CLP             ;SAVE AS CLP
        JMP     BYT
;
;*********************************************************
;*                                                       *
;*                       VERIFY                          *
;*                                                       *
;* FORMAT:                                               *
;*                                                       *
;*  >< VERIFY SYMB XXXX YYYY ZZ  - FOR SYMBOLIC          *
;*  >< VERIFY BYTE XXXX YYYY ZZ  - FOR LOCATIONS         *
;*                                                       *
;* LISTS ADDRESSES OF ALL OCCURENCES OF ZZ BETWEEN       *
;* ADDRESSES XXXX AND YYYY.                              *
;*                                                       *
;* SPACE CAN BE SUBSTITUTED FOR <CR> AT END OF LINE IF   *
;* IN SYMBOLIC MODE.                                     *
;*                                                       *
;*********************************************************
;
; VERIFY DATA BYTE LOCATION SYMBOLICALLY COMMAND.
;
VERIFS: CALL    GHXW            ;START ADDR TO HL
        JC      ILLCH           ;GRIPE & EXIT IF ILLEGAL
        XCHG                    ;PUT ADDR IN DE
        CALL    PU3             ;START TO HL, END TO DE
        CALL    SGHXB           ;SEND SPACE, GET DESIRED BYTE
        JC      ILLCH           ;GRIPE & EXIT IF BAD BYTE
        MOV     C,A             ;PUT BYTE IN 'C'
VER1:   MOV     A,M             ;GET MEMORY BYTE
        CMP     C               ;COMPARE TO C
        JNZ     VER4            ;NO MATCH?
VER3:   SHLD    CLP             ;SAVE FOUND ADDR IN CLP
        PUSH    H
        PUSH    D
        PUSH    B               ;SAVE ALL STATUS
        CALL    LMNUM           ;PRINT THE DB SYMBOLICALLY
        POP     B
        POP     D
        POP     H
VER4:   CALL    HILOEX          ;INCREMENT POINTER
        JMP     VER1            ;LOOK AGAIN
;
; THE FOLLOWING VERIFY ROUTINE PRINTS ONLY THE ADDRESSES
; OF OCCURANCE.
;
VERIFB: CALL    APARAM          ;GET PARAMETERS
        CALL    SGHXB           ;SEND SPACE, GET BYTE TO FIND
        MOV     B,A             ;SAVE COPY IN B
        CALL    CRLF            ;TURN UP A NEW LINE
VFB1:   MOV     A,M             ;READ A BYTE
        CMP     B               ;COMPARE WITH REF
        JNZ     VFB2            ;SKIP DOWN IF NO MATCH
        CALL    STHXW           ;SPACE VICE CRLF TO SAVE PAPER...THEN TYPE ADDRESS
VFB2:   CALL    HILOEX          ;INCR PNTR & CHECK IF DONE
        JMP     VFB1            ;KEEP SEARCHING IF NOT DONE

;*********************************************************
; Port Out

POUT:   MVI     A,0D3H          ;Out instruction
        STA     TR0
        LXI     H,M76
        CALL    MSG             ;Print "PORT:"
        CALL    SPCBY           ;Get dest port number
        STA     TR1
        MVI     A,0C9H          ;Ret instruction
        STA     TR2
        LXI     H,M77
        CALL    MSG             ;Print "VALUE:"
        CALL    SPCBY           ;Get value
        CALL    TR0             ;Call the trampoline
        CALL    CRLF
        JMP     RESET

PIN:    MVI     A,0DBH          ;In instruction
        STA     TR0
        LXI     H,M76
        CALL    MSG             ;Print "PORT:"
        CALL    SPCBY           ;Get dest port number
        STA     TR1
        MVI     A,0C9H          ;Ret instruction
        STA     TR2
        LXI     H,M77
        CALL    TR0             ;Call the trampoline
        CALL    CRLF
        CALL    THXB            ;Print hex value
        CALL    CRLF
        JMP     RESET

;*********************************************************
; DECHO
;
; Test IOC Slave processor by sending an 8-bit value. IOC will
; negate the value and return it.
;

CDECHO  EQU     07H             ; DATA ECHO TEST COMMAND
OBF     EQU     00000001B       ; SLAVE OUTPUT BUFFER IS FULL
IBF     EQU     00000010B       ; SLAVE INPUT BUFFER IS FULL
F0      EQU     00000100B       ; FLAG 0 - SLAVE IS BUSY, MASTER IS LOCKED OUT
IOCI    EQU     0C0H            ; I/O CONTROLLER INPUT DATA (FROM DBB) PORT
IOCO    EQU     0C0H            ; I/O CONTROLLER OUTPUT DATA (TO DBB) PORT
IOCS    EQU     0C1H            ; I/O CONTROLLER INPUT DBB STATUS PORT
IOCC    EQU     0C1H            ; I/O CONTROLLER OUTPUT CONTROL COMMAND PORT

DECHO:  LXI     H,M77           ;Print "VALUE:"
        CALL    MSG
        CALL    SPCBY
        MOV     B,A             ;save value
        CALL    CRLF
        CALL    WIDLE           ;wait for slave idle
        MVI     A,CDECHO
        OUT     IOCC
        CALL    WIDLE
        MOV     A,B             ;restore value
        OUT     IOCO
        CALL    WRDY
        IN      IOCI
        CALL    THXB
        CALL    CRLF
        JMP     RESET

WIDLE:  IN      IOCS            ; INPUT DBB STATUS
        ANI     F0 OR IBF OR OBF; TEST FOR SLAVE PROCESSOR IDLE
        JNZ     WIDLE           ; LOOP UNTIL IT IS IDLE
        RET

WRDY:   IN      IOCS            ; INPUT DBB STATUS
        ANI     IBF OR OBF OR F0; MASK OFF STATUS FLAGS
        CPI     OBF             ; TEST FOR SLAVE DONE; SOMETHING FOR THE MASTER
        JNZ     WRDY            ; IF NOT, CONTINUE TO LOOP
        RET

;
;*********************************************************
;*                                                       *
;*                       REGS                            *
;*                                                       *
;* EXAMINE AND MODIFY CPU REGISTERS COMMAND...           *
;*                                                       *
;* REGS DISPLAY    - DISPLAYS ALL REGISTERS              *
;*                                                       *
;* REGS EXAM/MOD                                         *
;*   - OR -                                              *
;* REGS MOD        - FOLLOWED BY REGISTER SYMBOL DISPLAY *
;*                   THAT REGISTER AND ALLOWS KYBD MOD   *
;*                                                       *
;* SPACE AFTER A REGISTER VALUE WILL CAUSE NEXT REGISTER *
;* TO BE DISPLAYED. <CR> WILL END THE REGISTER COMMAND.  *
;*                                                       *
;*********************************************************
;
REGX:   CALL    DSPREG
        JMP     RESET
;
;*********************************************************
;*                                                       *
;*               MODIFY REGISTERS                        *
;*                                                       *
;*********************************************************
;
MODREG: LXI     H,ACTBL         ;POINT TO START OF TABLE
        CALL    PCHK            ;INPUT CHARACTER
        CALL    TOUPPER
        JC      ERRORE          ;CAN'T BE CR
X0:     CMP     M               ;CHECK AGAINST TABLE
        JZ      X1              ;JUMP IF A MATCH
        PUSH    PSW
        MOV     A,M             ;GET TABLE ENTRY
        ORA     A               ;SET FLAGS
        JM      ERRORE          ;EXIT IF END OF TABLE WITHOUT MATCH
        INX     H               ;POINT TO NEXT
        INX     H               ; TABLE ENTRY
        INX     H
        POP     PSW
        JMP     X0              ;CHECK NEXT ENTRY
;
X1:     CALL    CRLF            ;TURN UP A NEW LINE
        MOV     A,M             ;GET REG FROM TABLE
        CALL    CHRSPC          ;PRINT CHAR AND A SPACE
        MVI     A,'='           ;PRINT EQUALS AND
        CALL    CHRSPC          ;A SPACE.
        INX     H
        MOV     A,M             ;GET REG LOCATION POINTER
        XCHG                    ;SAVE HL
        MOV     L,A
        MVI     H,0
        DAD     SP
        XCHG                    ;GET HL BACK
        INX     H
        MOV     B,M             ;GET #BYTES PER REGISTER
        INX     H
        LDAX    D
        DCR     B
        JZ      X2              ;PRINT  8 BIT REG
        CALL    DS3             ;PRINT 16 BIT REG
        JMP     X3
;
X2:     CALL    THXB            ;PRINT HEX BYTE
X3:     INR     B
        CALL    PSLASH          ;PRINT SLASH
        CALL    GHXB            ;GET A HEX BYTE
        JNC     X31             ;SKIP DOWN IF VALID HEX
        CPI     ' '             ;SPACE ENTERED?
        JZ      X5              ;OPEN NEXT LOC IF SO
        JMP     RESET           ;EXIT IF C/R, ETC.
;
X31:    PUSH    B
        DCR     B               ;CHECK IF ALL 2 OR 4 BYTES GOTTEN
        JZ      X32             ;JMP IF ALL BYTES ENTERED ALREADY
        PUSH    PSW             ;SAVE 1ST BYTE ENTERED
        CALL    GHXB            ;NEED A 2ND BYTE
        JC      RESET           ;EXIT IF BAD ENTRY
        STAX    D
        INX     D
        POP     PSW             ;RESTORE 1ST BYTE
X32:    STAX    D
X4:     POP     B
X5:     MOV     A,M             ;GET TABLE ENTRY
        ORA     A               ;SET FLAGS
        JM      X6              ;START AT BEGINNING IF AT END OF TABLE
        MOV     A,B             ;GET CHARACTER TYPED
        CPI     CR              ;IS IT A CR?
        JZ      RESET           ;EXIT IF SO
        JMP     X1              ;NEXT REGISTER
X6:     LXI     H,ACTBL         ;SET AT START OF TABLE
        CALL    CRLF            ;PRINT A BLANK LINE
        JMP     X1              ;NEXT LINE
;
;*********************************************************
;*                                                       *
;*               DISPLAY REGISTERS                       *
;*                                                       *
;*********************************************************
;
DSPREG: LXI     H,ACTBL         ;FULL REGISTER DISPLAY
        CALL    CRLF
        JMP     DS1+3
;
DS1:    CALL    SPACE
        MOV     A,M
        INX     H
        ORA     A
        RM                      ;RETURN
        CALL    TYPE
        CALL    PEQU
        MOV     E,M
        INX     H
        PUSH    H
        MVI     D,0
        LXI     H,STACK
        DAD     D
        XCHG
        POP     H
        MOV     B,M
        INX     H
        DCR     B
        LDAX    D
        JZ      DS2
        CALL    DS3
        JMP     DS1
;
DS2:    CALL    THXB
        JMP     DS1
;
DS3:    PUSH    H               ;ITS DOUBLE PRECISION, DISPLAY AS ADDRESS
        LDAX    D
        MOV     H,A
        DCX     D
        LDAX    D
        MOV     L,A
        CALL    THXW
        POP     H
        RET
;
;*********************************************************
;*                                                       *
;*                       RESTART                         *
;*                                                       *
;*********************************************************
;
; RESTART 1 ROUTINE...
;
; THIS ROUTINE SAVES THE COMPLETE STATE OF THE
; MACHINE AND RETURNS CONTROL TO THE MONITOR.
;
RESTART: PUSH   H
        PUSH    D
        PUSH    B
        PUSH    PSW
        LXI     H,CORE-14H
        XCHG
        LXI     H,0AH
        DAD     SP
;
        MVI     B,4
        XCHG
RST0:   DCX     H
        MOV     M,D
        DCX     H
        MOV     M,E
        POP     D
        DCR     B
        JNZ     RST0
        POP     B
        DCX     B
        SPHL
        LXI     H,TLOC
        DAD     SP
;
        MOV     A,M
        SUB     C
        INX     H
        JNZ     RST1
        MOV     A,M
        SUB     B
        JZ      RST3
RST1:   INX     H
        INX     H
        MOV     A,M
        SUB     C
        JNZ     RST2
        INX     H
        MOV     A,M
        SUB     B
        JZ      RST3
RST2:   INX     B
RST3:   LXI     H,LLOC
        DAD     SP
;
        MOV     M,E
        INX     H
        MOV     M,D
        INX     H
        INX     H
        MOV     M,C
        INX     H
        MOV     M,B
        PUSH    B
        POP     H
        SHLD    CLP             ;SAVE BREAKPOINT ADDRESS
        SHLD    FINCLP          ;AS START AND FINAL FOR LIST SYM
        LXI     H,TLOC
        DAD     SP
;
        MVI     D,2
RST4:   MOV     C,M
        MVI     M,0FFH
        INX     H
        MOV     B,M
        MVI     M,0FFH
        INX     H
        MOV     A,C
        ANA     B
        INR     A
        JZ      RST5
        MOV     A,M
        STAX    B
RST5:   INX     H
        DCR     D
        JNZ     RST4
        JMP     TRCON1          ;CONTINUE ELSEWHERE
;
QUIT:   JMP     0000			;EXIT TO CP/M

TOUPPER:
        ; if the character in A is lower case, convert it to upper case
        CPI     'a'             ; check if character is lower case
        RC                      ; if less than 'a', return
        CPI     'z'+1           ; check if character is greater than 'z'
        RNC                     ; if greater than 'z', return
        SUI     'a'-'A'         ; convert to upper case
        RET

;*********************************************************
;*                                                       *
;*               MONITOR I/O ROUTINES                    *
;*                                                       *
;*********************************************************
;
; GETCH...
;
; CALLING SEQUENCE
;
;       CALL    GETCH           ;GET CHARACTER
;       ....                    ;RETURN HERE WITH CHARACTER
;                               ;IN 'A'
;
; ALL REGISTERS PRESERVED EXCEPT 'A' WHICH
; CONTAINS THE INPUT CHARACTER
;
GETCH:  PUSH   H				;SAVE REGISTERS
        PUSH   D
        PUSH   B 
CIN	IN 	CONST		;GET STATUS OF CONSOLE 
	ANI 	RRDY		;CHECK FOR RECEIVER BUFFER READY 
	JZ 	CIN		;WAIT till recieved 
	IN      CNIN		;GET CHARACTER 
        POP    B                ;RESTORE REGISTERS
        POP    D
        POP    H
        RET                      ;RETURN
;
;
POLL:   IN	CONST		;GET STATUS OF CONSOLE 
	ANI 	RRDY		;CHECK FOR RECEIVER BUFFER READY 
        RET                     ;RETURN
;
;
; ROUTINE TO CHECK FOR SOFTWARE INTERUPT
;
CHECK:  CALL    POLL            ;CHECK FOR INPUT DATA
        RZ                      ;RETURN IF NONE
        
;
; ASCII INPUT ROUTINE
;
ASCIN:  CALL    GETCH           ;GET A CHARACTER
        ANI     7FH             ;STRIP OFF PARITY
        PUSH    PSW             ;SAVE IT TEMPORARILY
        CALL    CHECK2          ;CHECK FOR SPECIAL CHARACTERS
        POP     PSW             ;RESTORE CHAR
        RET                     ;RETURN
;
CHECK2: CPI     CTRLS           ;CHECK FOR CTRL-S HALT
        JZ      HANG            ;GO HANG UP IF SO
        CPI     CTRLC           ;CTRL-C ABORT?
        JZ      ABORT           ;ABORT IF SO
        CPI     CTRLO           ;SUPPRESS PRINTING?
        RNZ
        LDA     LSTSUPFLAG      ;GET LIST SUPPRESSION FLAG
        INR     A               ;REVERSE ITS STATE
        STA     LSTSUPFLAG      ;STORE IT AGAIN
        RET                     ;RETURN
;
; HANGS UP HERE WHEN CONTROL-S IS TYPED TO SUPPRESS OUTPUT
;
; ONLY AN ABORT COMMAND OR CONTROL-S WILL CONTINUE OUTPUT
;
HANG:   CALL    GETCH           ;GET CHARACTER
        ANI     7FH             ;STRIP PARITY
        CPI     CTRLC           ;CTRL-C ABORT?
        JZ      ABORT           ;ABORT IF YES
        CPI     CTRLS           ;ANOTHER CTRL-S?
        JNZ     HANG            ;CONTINUE HANGING IF NOT
        RET                     ;BACK TO NORMAL
;
;
ABORT:  MVI     A,5EH           ;('^') ECHO THE CTRL-C
        CALL    TYPE            ; WITH A
        MVI     A,'C'           ;  ^C
        CALL    TYPE            ;
        XRA     A               ;GET A ZERO
        STA     TMPA            ;
        JMP     RESET           ;CONTINUE BELOW
;
;
; ERROR...
;
; THIS IS AN ERROR EXIT ROUTINE. THE STACK IS REINITIALIZED AND
; CONTROL RETURNED TO THE MONITOR.
;
; NEED TO COMBINE WITH ILLCH, MOVE 'RESET' UP BELOW 'ABORT'
; AND GENERAL CLEAN-UP.
;
ERRORE: LXI     H,M3
RESCON: CALL    MSG             ;OUTPUT CRLF THE MESSAGE
;
RESET:  XRA     A               ;CLEAR A
        STA     TRCONFLAG       ;CLEAR TRACON FLAG
        STA     LSTSUPFLAG      ;CLEAR LIST SUPPRESSION FLAG
        JMP     NEXT            ;RETURN TO USER
;
;
; PAN...
;
; PUNCH A NULL CHARACTER
;
PAN:    XRA     A               ;LOAD A WITH A NULL
;
;
; ROUTINE TO TYPE A CHARACTER
;
; CALLING SEQUENCE
;
;       LDA     CHAR            ;CHARATER IN 'A' REGISTER
;       CALL    TYPE            ;TYPE IT
;       ....                    ;RETURNS HERE
;
TYPE:   PUSH    PSW             ;SAVE CONTENTS OF 'A'
        CALL    CHECK           ;CHECK FOR ABORT FIRST
        LDA     LSTSUPFLAG      ;GET LIST SUPPRESSION FLAG
        RRC                     ;TO CHECK BIT 0
        JNC     TYPE0           ;JUMP IF NOT SUPPRESSED
        POP     PSW             ;RESTORE A
        RET                     ;AND RETURN
;
TYPE0:  POP     PSW             ;GET CHAR BACK
        CALL    OUT1            ;SEND THE CHARACTER
        CPI     LF              ;WAS IT A LINE FEED
        RNZ                     ;RETURN IF NOT
        PUSH    B               ;SAVE BC
        PUSH    PSW             ;AND THE CHARACTER
        MVI     B,2             ;NUMBER OF FILLS TO B
        XRA     A               ;GET FILL CHARACTER
TYPE1:  CALL    OUT1            ;SEND A FILL CHARACTER
        DCR     B               ;DECREMENT COUNTER
        JNZ     TYPE1           ;LOOP BACK IF NOT DONE
TYPE2:  POP     PSW             ;RESTORE A AND FLAGS
        POP     B               ;RESTORE B
        RET                     ;RETURN
;
;*********************************************************
;*                                                       *
;*					Character Out                        *
;*                                                       *
;*  use:  MOV	A,character                              *
;*        CALL	OUT1                                     *
;*********************************************************
OUT1:	PUSH    B		;save BC
        PUSH    PSW
	MOV     C,A
COUT: 	IN 	CONST	        ;GET STATUS OF CONSOLE 
        ANI 	TRDY	        ;SEE IF TRANSMITTER READY 
	JZ  	COUT	        ;NO - WAIT till ready
	MOV 	A,C		;move CHARACTER TO A REG 
	OUT 	CNOUT	        ;SEND Character TO CONSOLE 
	POP     PSW
	POP     B               ;restore BC
	RET
			
;
; EXIT CODE TEMPLATE
;
; RESTORES MACHINE STATE AND RETURNS TO PROGRAM EXECUTION.
;
EXITC:  POP     D			;RESTORE REGISTERS
        POP     B
        POP     PSW
        POP     H
        SPHL				;SET STACK POINTER
        EI					;ENABLE INTERUPTS
        LXI     H,0			;ZERO HL
;
HLX     .EQU     $-2
;
        JMP     0
;
PCX     .EQU     $-2
;
T1A:    .DW      0FFFFH
        .DB      0
        .DW      0FFFFH
        .DB      0
;
; DISPLACEMENT OF REGISTER LOCATION FROM SP (LEVEL 0)
;
ENDX:
ALOC    .EQU     5
BLOC    .EQU     3
CLOC    .EQU     2
DLOC    .EQU     1
ELOC    .EQU     0
FLOC    .EQU     4
HLOC    .EQU     HLX-EXITC+09H
LLOC    .EQU     HLX-EXITC+08H
PLOC    .EQU     PCX-EXITC+09H
SLOC    .EQU     7
TLOC    .EQU     T1A-EXITC+08H
;
; TABLE FOR ACCESSING REGISTERS
;
ACTBL:
        .DB      'A',ALOC,1
        .DB      'B',BLOC,1
        .DB      'C',CLOC,1
        .DB      'D',DLOC,1
        .DB      'E',ELOC,1
        .DB      'F',FLOC,1
        .DB      'H',HLOC,1
        .DB      'L',LLOC,1
        .DB      'M',HLOC,2
        .DB      'P',PLOC,2
        .DB      'S',SLOC,2
        .DB      0FFH
;
; ASSEM/DISSEM LOOK-UP TABLES
;
FOURTBL:
        .DB      03H,81H,8CH,0CH,0CDH    ;CALL
        .DB      50H,15H,93H,08H,0FDH    ;PUSH
        .DB      18H,03H,88H,07H,0EBH    ;XCHG
        .DB      13H,88H,8CH,04H,22H     ;SHLD
        .DB      0CH,88H,8CH,04H,2AH     ;LHLD
        .DB      53H,14H,81H,18H,3AH     ;STAX
        .DB      4CH,04H,0C1H,18H,3AH    ;LDAX
        .DB      18H,03H,88H,07H,0EBH    ;XCHG
        .DB      18H,14H,88H,0CH,0E3H    ;XTHL
FOURT1: .DB      13H,10H,88H,0CH,0F9H    ;SPHL
        .DB      10H,03H,88H,0CH,0E9H    ;PCHL
;
TWOTBL: .DB      0AH,83H,0DAH            ;JC    TWO LETTER LOOK UP TABLE
        .DB      0AH,9AH,0CAH            ;JZ
        .DB      0AH,90H,0F2H            ;JP
        .DB      0AH,8DH,0FAH            ;JM
        .DB      03H,83H,0DCH            ;CC
        .DB      03H,9AH,0CCH            ;CZ
        .DB      03H,90H,0F4H            ;CP
        .DB      03H,8DH,0FCH            ;CM
        .DB      12H,03H,0D8H            ;RC
        .DB      12H,1AH,0C8H            ;RZ
        .DB      12H,10H,0F0H            ;RP
        .DB      12H,0DH,0F8H            ;RM
        .DB      09H,4EH,0DBH            ;IN
        .DB      05H,09H,0FBH            ;EI
        .DB      04H,09H,0F3H            ;DI
;
REGTBL: .DB      'B',0F8H,'C',0F9H       ;REGISTER LOOP UP TABLE
        .DB      'D',0FAH,'E',0FBH
        .DB      'H',0FCH,'L',0FDH,'M',0FEH
        .DB      'S',0FEH,'P',0FEH,'A',0FFH
;
; COMMAND BRANCH TABLE FOR ASSEMBLER
;
; NOTE: IF ANY MACROS ARE ADDED TO OR DELETED FROM THIS TABLE,
;       CHANGE THE TABLE LENGTH IN 'SETBCT'
;
PSOPR:  .DB      "LST"           ;LIST CODE SO FAR
        .DW      DSYM1
        .DB      "RUN"           ;JUMP TO ADDRESS
        .DW      MRUN
        .DB      "BYT"           ;ENTER BYTES MODE
        .DW      BYT
        .DB      "ORG"           ;NEW START ADDRESS FOR ASSEMBLER
        .DW      LOSYM
        .DB      "ASC"           ;ENTER ASCII INPUT MODE
        .DW      ASCII
        .DB      "PRT"           ;PRINT MACRO, CALL MESSAGE ETC
        .DW      PRTMG
        .DB      "TTI"           ;CONSOLE INPUT MACRO
        .DW      MTTI
        .DB      "TTO"           ;CONSOLE OUTPUT MACRO
        .DW      MTTO
        .DB      "TTE"           ;CONSOLE INPUT/ECHO MACRO
        .DW      MTTE
        .DB      "BIN"           ;BINARY INPUT MACRO
        .DW      MBIN
        .DB      "LBY"           ;LIST BYTE MACRO
        .DW      MLBY
        .DB      "LWD"           ;LIST WORD MACRO
        .DW      MLWD
        .DB      "IPW"           ;INPUT WORD MACRO
        .DW      MIPW
        .DB      "NWL"           ;NEW LINE MACRO
        .DW      MNWL
        .DB      "SPC"           ;MACRO PRINT A SPACE CHAR
        .DW      MSPC
        .DB      "DLY"           ;MACRO LONG DELAY
        .DW      MDLY
;
; ASSEM/DISSEM LOOK-UP TABLES
;
THREETBL:
        .DB      03H,0DH,03H,3FH         ;CMC
        .DB      8DH,0FH,16H,7FH         ;MOV
        .DB      08H,0CH,14H,76H         ;HLT
        .DB      4DH,56H,09H,3EH         ;MVI
        .DB      49H,0EH,12H,3CH         ;INR
        .DB      44H,03H,12H,3DH         ;DCR
        .DB      0C1H,04H,04H,87H        ;ADD
        .DB      0C1H,04H,03H,8FH        ;ADC
        .DB      0D3H,15H,02H,97H        ;SUB
        .DB      0D3H,02H,02H,9FH        ;SBB
        .DB      0C1H,0EH,01H,0A7H       ;ANA
        .DB      0D8H,12H,01H,0AFH       ;XRA
        .DB      0CFH,12H,01H,0B7H       ;ORA
        .DB      0C3H,0DH,10H,0BFH       ;CMP
        .DB      01H,44H,09H,0C6H        ;ADI
        .DB      01H,43H,09H,0CEH        ;ACI
        .DB      13H,55H,09H,0D6H        ;SUI
        .DB      13H,42H,09H,0DEH        ;SBI
        .DB      01H,4EH,09H,0E6H        ;ANI
        .DB      18H,52H,09H,0EEH        ;XRI
        .DB      0FH,52H,09H,0F6H        ;ORI
        .DB      03H,50H,09H,0FEH        ;CPI
        .DB      12H,0CH,03H,07H         ;RLC
        .DB      12H,12H,03H,0FH         ;RRC
        .DB      12H,01H,0CH,17H         ;RAL
        .DB      12H,01H,12H,1FH         ;RAR
        .DB      0AH,8DH,10H,0C3H        ;JMP
        .DB      0AH,8EH,03H,0D2H        ;JNC
        .DB      0AH,8EH,1AH,0C2H        ;JNZ
        .DB      0AH,90H,05H,0EAH        ;JPE
        .DB      0AH,90H,0FH,0E2H        ;JPO
        .DB      03H,8EH,03H,0D4H        ;CNC
        .DB      03H,8EH,1AH,0C4H        ;CNZ
        .DB      03H,90H,05H,0ECH        ;CPE
        .DB      03H,90H,0FH,0E4H        ;CPO
        .DB      12H,05H,14H,0C9H        ;RET
        .DB      12H,0EH,03H,0D0H        ;RNC
        .DB      12H,0EH,1AH,0C0H        ;RNZ
        .DB      12H,10H,05H,0E8H        ;RPE
        .DB      12H,10H,0FH,0E0H        ;RPO
        .DB      0FH,55H,14H,0D3H        ;OUT
        .DB      0CH,84H,01H,3AH         ;LDA
        .DB      50H,0FH,10H,0F9H        ;POP
        .DB      13H,94H,01H,32H         ;STA
        .DB      4CH,98H,09H,39H         ;LXI
        .DB      44H,01H,44H,39H         ;DAD
        .DB      49H,0EH,18H,3BH         ;INX
        .DB      44H,03H,58H,3BH         ;DCX
        .DB      03H,0DH,01H,2FH         ;CMA
        .DB      13H,14H,03H,37H         ;STC
        .DB      04H,01H,01H,27H         ;DAA
        .DB      0EH,0FH,10H,00H         ;NOP
        .DB      52H,13H,14H             ;RST
TABEND: .DB      0FFH
;
; TABLE CONTAINING CODES FOR SHLD LHLD STA LDA LXI
;
        .DB      22H,2AH,32H,3AH,39H,21H,31H,11H,01H
        .DB      0
;
;*********************************************************
;*                                                       *
;*               SYSTEM MESSAGES                         *
;*                                                       *
;*********************************************************
;
M0:     .DB      CR,LF,"8080 SYSTEM MONITOR",LF+80H
M2:     .DB      " IS UNDEFINE",'D'+80H
M3:     .DB      " ?",'?'+80H
M4:     .DB      "MEMORY WRITE ERROR AT",' '+80H
M5:     .DB      " PAUSE",' '+80H
M6:     .DB      "CHECKSUM ERROR, BLOCK",' '+80H
M7:     .DB      "  OK?",' '+80H
M8:     .DB      " ABORTED..",'.'+80H
M9:     .DB      "ERROR AT ADDR/WRITE/READ -",' '+80H
M10:    .DB      "  TEST O",'K'+80H
M13:    .DB      'A','P'+80H
M14:    .DB      "OAD",' '+80H
M25:    .DB      'S','P'+80H
M27:    .DB      "UM",'P'+80H
M28:    .DB      "OTO",' '+80H
M29:    .DB      "OV",'E'+80H
M30:    .DB      "IL",'L'+80H
M31:    .DB      "ES",'T'+80H
M32:    .DB      "DDRES",'S'+80H
M34:    .DB      "ERIFY",' '+80H
M35:    .DB      'E','X'+80H
M38:    .DB      "YMBOLIC",' '+80H
M46:    .DB      " NUM?",' '+80H
M51:    .DB      "UNCH",' '+80H
M57:    .DB      "TEP",' '+80H
M58:    .DB      "RAC",'E'+80H
M64:    .DB      "ULL",'S'+80H
M66:    .DB      "EGISTER",' '+80H
M67:    .DB      'O','F'+80H
M68:    .DB      "XAMINE/MODIFY",' '+80H
M69:    .DB      "ISPLA",'Y'+80H
M70:    .DB      "EL",'P'+80H
M71:    .DB      CR,LF,"ADDRESS XXXX"
        .DB      CR,LF,"BASIC"
        .DB      CR,LF,"DUMP HEX XXXX YYYY"
        .DB      CR,LF,"DUMP SYMBOLIC XXXX YYYY"
        .DB      CR,LF,"FILL XXXX YYYY ZZ"
        .DB      CR,LF,"HELP"        
        .DB      CR,LF,"JUMP XXXX"
        .DB      CR,LF,"LOAD HEX XXXX"
        .DB      CR,LF,"LOAD SYMBOLIC XXXX"
        .DB      CR,LF,"MOVE XXXX YYYY ZZZZ"
        .DB      CR,LF,"TEST XXXX YYYY"
        .DB      CR,LF,"PUNCH EOF"
        .DB      CR,LF,"PUNCH NULLS"
        .DB      CR,LF,"PUNCH HEX XXXX YYYY"
        .DB      CR,LF,"REGISTER DISPLAY"
        .DB      CR,LF,"REGISTER MODIFY X"
        .DB      CR,LF,"U-FORTH"     
        .DB      CR,LF,"VERIFY HEX XXXX YYYY ZZ"
        .DB      CR,LF,"VERIFY SYMBOLIC XXXX YYYY ZZ"
        .DB      CR,LF,"ZAP XXXX YYY",'Y'+80H
M72:    .DB      "ASI",'C'+80H
M73:    .DB      "-FORT",'H'+80H
M74:    .DB      '.'+80H
M75:    .DB      "-BURN TES",'T'+80H
M76:    .DB      " POR",'T'+80H
M77:    .DB      " VALU",'E'+80H
M78:    .DB      "U",'T'+80H
M79:    .DB      'N'+80H
M80:    .DB      "-DECH",'O'+80H
M81:    .DB      "-ISI",'S'+80H
M82:    .DB      CR,LF,"COPYING ISIS BOOTER FROM ROM TO RAM",CR,LF+80H
M83:    .DB      CR,LF,"JUMPING TO ISIS BOOTER IN ROM",CR,LF+80H
;
PSWMG:  .DB      "PS",'W'+80H
;
RXLST:  .DB      "AFBCDEHL",0            ;RESISTER LIST
;
ENDROM  .EQU     $                       ;BOUNDRY MARKER
;
        .ORG     RAM                     ;SOME RAM SCRATCHPAD AREA
;
; SYSTEM RAM AREA
;
TR0:    .DS      1               ;TRAMPOLINE - OUT/IN INSTR
TR1:    .DS      1               ;TRAMPOLINE - VALUE
TR2:    .DS      1               ;TRAMPOLINE - RET INSTR

TMPA:   .DS      1               ;TEMP STORAGE LOCATION
ECHO:   .DS      1               ;CHIN ECHO FLAG, <>0=ECHO
                                 ; =0 = NO ECHO
ADR:    .DS      2               ;EXAMINE/MODIFY ADDRESS
XEQAD:  .DS      2               ;EXECUTION ADDRESS
BLKAD:  .DS      2               ;LOAD BLOCK ADDRESS
ERRFL:  .DS      1               ;MEMORY TEST ERROR FLAG
;
BEGADR: .DS      2               ;TEMP START ADDR STORAGE
ENDADR: .DS      2               ;TEMP STOP  ADDR STORAGE
ISRVEC: .DS      3               ;VECTOR TO INTERUPT SERVICE ROUTINE
;
;
; FOLLOWING ARE RAM AREAS FOR MULTI-RADIX ASSEMBLY/DISASSEMBLY
;
CLP:    .DS      2               ;CURRENT LOCATION POINTER
FINCLP: .DS      2               ;FINAL CURRENT LOCATION POINTER
OPCADR: .DS      2               ;OPCODE ADDR
PREADR: .DS      2               ;PREVIOUS OPCODE ADDRESS
ADFLAG: .DS      1
EXFLAG: .DS      1
DBFLAG: .DS      1
AUGFLAG: .DS     1
MATCHFLAG: .DS   2
TEMPWORD: .DS    3
LASTOPC: .DS     3               ;LAST OP
TRCONFLAG: .DS   2               ;TRACE CONTINUOUS FLAG
LSTSUPFLAG: .DS  1               ;SUPPRESS LISTING FLAG
;
        .END
