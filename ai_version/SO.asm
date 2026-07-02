; =====================================================================
;  ICMC-OS : um "sistema operacional" de brincadeira (terminal)
; ---------------------------------------------------------------------
;  Simula um terminal: mostra um prompt "> ", le um comando digitado
;  (com eco, backspace e enter) e executa:
;     HELP    - lista os comandos
;     CLEAR   - limpa a tela
;     PONG    - roda o jogo Pong (2 jogadores; W/S e I/K; Q sai)
;     DIGITAR - roda o jogo de digitacao
;     SAIR    - encerra (halt)
;  Os dois jogos sao subrotinas (RunPong / RunTyping) que voltam ao
;  terminal quando terminam.
;
;  Teclado: MAIUSCULAS (A=65), espaco=32, backspace=8, enter=13.
;  Cores (offset + ASCII): branco=0  verde=7168  vermelho=57344
;                          amarelo=64512
; =====================================================================

; ---------------------------------------------------------------------
;  Programa principal / laco do terminal
; ---------------------------------------------------------------------
main:
	call ShellInit
	SMLoop:
		call NewPromptLine     ; desenha "> " e zera o buffer
		call ReadCommand       ; le a linha ate' o ENTER
		call ParseExec         ; identifica e executa o comando
		jmp SMLoop

; ---------------------------------------------------------------------
;  ShellInit - limpa a tela e desenha o banner do terminal
; ---------------------------------------------------------------------
ShellInit:
	push r0
	push r1
	push r2
	call ClearScreen
	loadn r0, #0
	loadn r1, #BANNER1
	loadn r2, #64512           ; amarelo
	call PrintStr
	loadn r0, #40
	loadn r1, #BANNER2
	loadn r2, #0
	call PrintStr
	pop r2
	pop r1
	pop r0
	rts

; ---------------------------------------------------------------------
;  NewPromptLine - limpa a linha do prompt (linha 4), desenha "> " e
;  reinicia CURX (cursor) e BUFLEN (tamanho do comando).
; ---------------------------------------------------------------------
NewPromptLine:
	push r0
	push r1
	push r2
	loadn r0, #160             ; linha 4
	loadn r1, #200
	loadn r2, #' '
	NPLc:
		outchar r2, r0
		inc r0
		cmp r0, r1
		jle NPLc
	loadn r0, #160
	loadn r1, #PROMPT
	loadn r2, #0
	call PrintStr
	loadn r0, #162             ; cursor logo apos "> "
	store CURX, r0
	loadn r0, #0
	store BUFLEN, r0
	pop r2
	pop r1
	pop r0
	rts

; ---------------------------------------------------------------------
;  ReadCommand - le caracteres ate' o ENTER, montando BUF.
;  Trata backspace (apaga) e ecoa cada caractere no cursor CURX.
; ---------------------------------------------------------------------
ReadCommand:
	push r0
	push r1
	push r2
	push r3
	RCLoop:
		call WaitKeyEdge       ; r0 = uma tecla (uma por pressionada)

		loadn r1, #13          ; ENTER -> fim do comando
		cmp r0, r1
		jeq RCEnter
		loadn r1, #8           ; BACKSPACE -> apaga
		cmp r0, r1
		jeq RCBack

		loadn r1, #32          ; ignora teclas de controle (<32)
		cmp r0, r1
		jle RCLoop
		load r1, BUFLEN        ; limite do buffer
		loadn r2, #28
		cmp r1, r2
		jeg RCLoop

		loadn r2, #BUF         ; BUF[BUFLEN] = tecla
		add r2, r2, r1
		storei r2, r0
		load r3, CURX          ; ecoa na tela
		outchar r0, r3
		inc r3
		store CURX, r3
		inc r1
		store BUFLEN, r1
		jmp RCLoop

	RCBack:
		load r1, BUFLEN
		loadn r2, #0
		cmp r1, r2
		jeq RCLoop             ; nada para apagar
		dec r1
		store BUFLEN, r1
		load r3, CURX
		dec r3
		store CURX, r3
		loadn r0, #' '
		outchar r0, r3
		jmp RCLoop

	RCEnter:
		load r1, BUFLEN        ; termina a string com '\0'
		loadn r2, #BUF
		add r2, r2, r1
		loadn r0, #0
		storei r2, r0
		pop r3
		pop r2
		pop r1
		pop r0
		rts

; ---------------------------------------------------------------------
;  WaitKeyEdge - espera pressionar UMA tecla e soltar; devolve em r0.
;  Garante 1 caractere por pressionada (deteccao de borda).
; ---------------------------------------------------------------------
WaitKeyEdge:
	push r1
	push r2
	loadn r1, #255
	WKE1:
		inchar r0
		cmp r0, r1
		jeq WKE1               ; espera pressionar
	mov r2, r0                 ; guarda a tecla
	WKE2:
		inchar r0
		cmp r0, r1
		jne WKE2               ; espera soltar
	mov r0, r2                 ; devolve a tecla
	pop r2
	pop r1
	rts

; ---------------------------------------------------------------------
;  ParseExec - compara BUF com cada comando e executa o que casar.
; ---------------------------------------------------------------------
ParseExec:
	push r0
	push r1
	push r2
	load r0, BUFLEN            ; comando vazio -> nada
	loadn r1, #0
	cmp r0, r1
	jeq PEEnd

	loadn r1, #BUF
	loadn r2, #CMD_HELP
	call StrEq
	loadn r1, #1
	cmp r0, r1
	jne PE1
		call DoHelp
		jmp PEEnd
	PE1:
	loadn r1, #BUF
	loadn r2, #CMD_CLEAR
	call StrEq
	loadn r1, #1
	cmp r0, r1
	jne PE2
		call ShellInit         ; CLEAR = redesenha tudo
		jmp PEEnd
	PE2:
	loadn r1, #BUF
	loadn r2, #CMD_PONG
	call StrEq
	loadn r1, #1
	cmp r0, r1
	jne PE3
		call RunPong
		call ShellInit         ; volta ao terminal
		jmp PEEnd
	PE3:
	loadn r1, #BUF
	loadn r2, #CMD_DIG
	call StrEq
	loadn r1, #1
	cmp r0, r1
	jne PE4
		call RunTyping
		call ShellInit
		jmp PEEnd
	PE4:
	loadn r1, #BUF
	loadn r2, #CMD_SAIR
	call StrEq
	loadn r1, #1
	cmp r0, r1
	jne PEUnknown
		halt                   ; SAIR = encerra

	PEUnknown:
		call DoUnknown
	PEEnd:
		pop r2
		pop r1
		pop r0
		rts

; ---------------------------------------------------------------------
;  StrEq - r1=endereco A, r2=endereco B ; devolve r0=1 se iguais.
;  (compara ate' o '\0' dos dois; preserva r1 e r2)
; ---------------------------------------------------------------------
StrEq:
	push r1
	push r2
	push r3
	push r4
	SELoop:
		loadi r3, r1
		loadi r4, r2
		cmp r3, r4
		jne SENeq
		loadn r4, #0           ; iguais: se chegou no '\0', iguais
		cmp r3, r4
		jeq SEEq
		inc r1
		inc r2
		jmp SELoop
	SEEq:
		loadn r0, #1
		jmp SEDone
	SENeq:
		loadn r0, #0
	SEDone:
		pop r4
		pop r3
		pop r2
		pop r1
	rts

; ---------------------------------------------------------------------
;  DoHelp / DoUnknown - imprimem na area de saida (linhas 6+)
; ---------------------------------------------------------------------
DoHelp:
	push r0
	push r1
	push r2
	call ClearOutput
	loadn r2, #0
	loadn r0, #240
	loadn r1, #HELP1
	call PrintStr
	loadn r0, #280
	loadn r1, #HELP2
	call PrintStr
	loadn r0, #320
	loadn r1, #HELP3
	call PrintStr
	loadn r0, #360
	loadn r1, #HELP4
	call PrintStr
	loadn r0, #400
	loadn r1, #HELP5
	call PrintStr
	pop r2
	pop r1
	pop r0
	rts

DoUnknown:
	push r0
	push r1
	push r2
	call ClearOutput
	loadn r0, #240
	loadn r1, #MSGINV
	loadn r2, #57344           ; vermelho
	call PrintStr
	pop r2
	pop r1
	pop r0
	rts

; ---------------------------------------------------------------------
;  ClearOutput - limpa a area de saida (linhas 6..29)
; ---------------------------------------------------------------------
ClearOutput:
	push r0
	push r1
	push r2
	loadn r0, #240
	loadn r1, #1200
	loadn r2, #' '
	COLoop:
		outchar r2, r0
		inc r0
		cmp r0, r1
		jle COLoop
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
; ====================  JOGO DE DIGITACAO  ============================
; =====================================================================
RunTyping:
	push r0
	push r1
	push r2
	push r3
	push r4
	push r5
	push r6
	push r7
	call ClearScreen
	loadn r0, #0
	loadn r1, #TITULO
	loadn r2, #64512
	call PrintStr
	loadn r0, #80
	loadn r1, #LBLTEMPO
	loadn r2, #0
	call PrintStr
	loadn r0, #160
	loadn r1, #LBLINSTR
	loadn r2, #0
	call PrintStr
	loadn r0, #240
	loadn r1, #TEXTO
	loadn r2, #0
	call PrintStr
	call CalcLen
	loadn r0, #0
	store IDX, r0
	store SEC, r0
	store SUBT, r0
	loadn r0, #255
	store LASTK, r0
	call ShowTime
	TLoop:
		inchar r0
		loadn r1, #255
		cmp r0, r1
		jeq TNoKey
		load r1, LASTK
		cmp r0, r1
		jeq TTick
		store LASTK, r0
		loadn r1, #32
		cmp r0, r1
		jle TTick
		call ProcessKey
		load r1, IDX
		load r2, LEN
		cmp r1, r2
		jeq TFinish
		jmp TTick
	TNoKey:
		loadn r0, #255
		store LASTK, r0
	TTick:
		call SmallDelay
		load r0, SUBT
		inc r0
		loadn r1, #100
		cmp r0, r1
		jne TSaveSub
			loadn r0, #0
			load r1, SEC
			inc r1
			store SEC, r1
			call ShowTime
		TSaveSub:
		store SUBT, r0
		jmp TLoop
	TFinish:
		call ShowTime
		loadn r0, #480
		loadn r1, #LBLFIM
		loadn r2, #7168
		call PrintStr
		call WaitAnyKey
	pop r7
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

ProcessKey:
	push r1
	push r2
	push r3
	push r4
	push r5
	push r6
	loadn r2, #TEXTO
	load r3, IDX
	add r2, r2, r3
	loadi r4, r2
	loadn r5, #240
	add r5, r5, r3
	cmp r0, r4
	jeq PKCorrect
		loadn r6, #57344
		add r4, r4, r6
		outchar r4, r5
		jmp PKAdv
	PKCorrect:
		loadn r6, #7168
		add r4, r4, r6
		outchar r4, r5
	PKAdv:
		inc r3
		store IDX, r3
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	rts

CalcLen:
	push r0
	push r1
	push r2
	push r3
	loadn r0, #TEXTO
	loadn r1, #0
	loadn r3, #'\0'
	CLLoop:
		loadi r2, r0
		cmp r2, r3
		jeq CLDone
		inc r0
		inc r1
		jmp CLLoop
	CLDone:
		store LEN, r1
	pop r3
	pop r2
	pop r1
	pop r0
	rts

ShowTime:
	push r0
	push r1
	push r2
	push r3
	push r4
	load r0, SEC
	loadn r1, #100
	div r2, r0, r1
	mod r0, r0, r1
	loadn r1, #10
	div r3, r0, r1
	mod r4, r0, r1
	loadn r0, #48
	add r2, r2, r0
	add r3, r3, r0
	add r4, r4, r0
	loadn r0, #87
	outchar r2, r0
	inc r0
	outchar r3, r0
	inc r0
	outchar r4, r0
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
; ==============================  PONG  ===============================
; =====================================================================
RunPong:
	push r0
	push r1
	push r2
	push r3
	push r4
	push r5
	push r6
	push r7
	loadn r0, #0
	store PONGOVER, r0
	call PongInit
	PongLoop:
		call PongInput
		load r0, PONGOVER
		loadn r1, #1
		cmp r0, r1
		jeq PongExit
		call MoveBall
		load r0, PONGOVER
		loadn r1, #1
		cmp r0, r1
		jeq PongExit
		call PongDelay
		jmp PongLoop
	PongExit:
	pop r7
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

PongInit:
	push r0
	push r1
	push r2
	push r3
	call ClearScreen
	loadn r0, #100             ; rede central (coluna 20, linhas 2..27)
	loadn r1, #1100
	loadn r2, #':'
	loadn r3, #40
	PNet:
		outchar r2, r0
		add r0, r0, r3
		cmp r0, r1
		jle PNet
	loadn r0, #12
	store P1Y, r0
	store P2Y, r0
	loadn r0, #20
	store BX, r0
	loadn r0, #15
	store BY, r0
	loadn r0, #0
	store VX, r0
	loadn r0, #1
	store VY, r0
	loadn r0, #0
	store SC1, r0
	store SC2, r0
	call DrawP1Full
	call DrawP2Full
	call DrawScore
	load r0, BY
	load r1, BX
	loadn r2, #64591
	call DrawCell
	pop r3
	pop r2
	pop r1
	pop r0
	rts

DrawCell:
	push r0
	push r3
	loadn r3, #40
	mul r0, r0, r3
	add r0, r0, r1
	outchar r2, r0
	pop r3
	pop r0
	rts

DrawP1Full:
	push r0
	push r1
	push r2
	push r3
	push r4
	load r0, P1Y
	loadn r3, #4
	loadn r4, #0
	P1FL:
		loadn r1, #1
		loadn r2, #7203
		call DrawCell
		inc r0
		inc r4
		cmp r4, r3
		jle P1FL
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

DrawP2Full:
	push r0
	push r1
	push r2
	push r3
	push r4
	load r0, P2Y
	loadn r3, #4
	loadn r4, #0
	P2FL:
		loadn r1, #38
		loadn r2, #57379
		call DrawCell
		inc r0
		inc r4
		cmp r4, r3
		jle P2FL
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

DrawScore:
	push r0
	push r1
	load r0, SC1
	loadn r1, #48
	add r0, r0, r1
	loadn r1, #5
	outchar r0, r1
	load r0, SC2
	loadn r1, #48
	add r0, r0, r1
	loadn r1, #34
	outchar r0, r1
	pop r1
	pop r0
	rts

PongInput:
	push r0
	push r1
	push r2
	inchar r0
	loadn r1, #81              ; 'Q' -> sair para o terminal
	cmp r0, r1
	jeq PQuit
	loadn r1, #119             ; 'w' P1 sobe
	cmp r0, r1
	jeq PP1Up
	loadn r1, #115             ; 's' P1 desce
	cmp r0, r1
	jeq PP1Down
	loadn r1, #105             ; 'i' P2 sobe
	cmp r0, r1
	jeq PP2Up
	loadn r1, #107             ; 'k' P2 desce
	cmp r0, r1
	jeq PP2Down
	jmp PIEnd

	PQuit:
		loadn r1, #1
		store PONGOVER, r1
		jmp PIEnd

	PP1Up:
		load r0, P1Y
		loadn r1, #1
		cmp r0, r1
		jle PIEnd
		jeq PIEnd
		loadn r1, #3
		add r0, r0, r1
		loadn r1, #1
		loadn r2, #' '
		call DrawCell
		load r0, P1Y
		dec r0
		store P1Y, r0
		loadn r1, #1
		loadn r2, #7203
		call DrawCell
		jmp PIEnd
	PP1Down:
		load r0, P1Y
		loadn r1, #25
		cmp r0, r1
		jeg PIEnd
		loadn r1, #1
		loadn r2, #' '
		call DrawCell
		load r0, P1Y
		inc r0
		store P1Y, r0
		loadn r1, #3
		add r0, r0, r1
		loadn r1, #1
		loadn r2, #7203
		call DrawCell
		jmp PIEnd
	PP2Up:
		load r0, P2Y
		loadn r1, #1
		cmp r0, r1
		jle PIEnd
		jeq PIEnd
		loadn r1, #3
		add r0, r0, r1
		loadn r1, #38
		loadn r2, #' '
		call DrawCell
		load r0, P2Y
		dec r0
		store P2Y, r0
		loadn r1, #38
		loadn r2, #57379
		call DrawCell
		jmp PIEnd
	PP2Down:
		load r0, P2Y
		loadn r1, #25
		cmp r0, r1
		jeg PIEnd
		loadn r1, #38
		loadn r2, #' '
		call DrawCell
		load r0, P2Y
		inc r0
		store P2Y, r0
		loadn r1, #3
		add r0, r0, r1
		loadn r1, #38
		loadn r2, #57379
		call DrawCell
		jmp PIEnd
	PIEnd:
		pop r2
		pop r1
		pop r0
		rts

MoveBall:
	push r0
	push r1
	push r2
	load r0, BY
	load r1, BX
	loadn r2, #' '
	call DrawCell
	load r0, VY
	loadn r1, #0
	cmp r0, r1
	jeq MBDown
		load r0, BY
		dec r0
		store BY, r0
		jmp MBX
	MBDown:
		load r0, BY
		inc r0
		store BY, r0
	MBX:
	load r0, VX
	loadn r1, #0
	cmp r0, r1
	jeq MBRight
		load r0, BX
		dec r0
		store BX, r0
		jmp MBWalls
	MBRight:
		load r0, BX
		inc r0
		store BX, r0
	MBWalls:
	load r0, BY
	loadn r1, #1
	cmp r0, r1
	jgr MBBottom
		loadn r0, #1
		store BY, r0
		loadn r0, #0
		store VY, r0
	MBBottom:
	load r0, BY
	loadn r1, #28
	cmp r0, r1
	jle MBLeft
		loadn r0, #28
		store BY, r0
		loadn r0, #1
		store VY, r0
	MBLeft:
	load r0, BX
	loadn r1, #2
	cmp r0, r1
	jne MBScoreL
		load r0, BY
		load r1, P1Y
		cmp r0, r1
		jle MBScoreL
		loadn r2, #3
		add r1, r1, r2
		cmp r0, r1
		jgr MBScoreL
		loadn r0, #0
		store VX, r0
		jmp MBDraw
	MBScoreL:
	load r0, BX
	loadn r1, #0
	cmp r0, r1
	jgr MBRightSide
		call ScoreP2
		jmp MBDraw
	MBRightSide:
	load r0, BX
	loadn r1, #37
	cmp r0, r1
	jne MBScoreR
		load r0, BY
		load r1, P2Y
		cmp r0, r1
		jle MBScoreR
		loadn r2, #3
		add r1, r1, r2
		cmp r0, r1
		jgr MBScoreR
		loadn r0, #1
		store VX, r0
		jmp MBDraw
	MBScoreR:
	load r0, BX
	loadn r1, #39
	cmp r0, r1
	jle MBDraw
		call ScoreP1
	MBDraw:
		load r0, BY
		load r1, BX
		loadn r2, #64591
		call DrawCell
	pop r2
	pop r1
	pop r0
	rts

ScoreP1:
	push r0
	load r0, SC1
	inc r0
	store SC1, r0
	call DrawScore
	loadn r1, #5
	cmp r0, r1
	jeq WinP1
	call ResetBallRight
	pop r0
	rts
	WinP1:
		call ClearScreen
		loadn r0, #575
		loadn r1, #MSGP1
		loadn r2, #7168
		call PrintStr
		call WaitAnyKey
		loadn r0, #1
		store PONGOVER, r0
		pop r0
		rts

ScoreP2:
	push r0
	load r0, SC2
	inc r0
	store SC2, r0
	call DrawScore
	loadn r1, #5
	cmp r0, r1
	jeq WinP2
	call ResetBallLeft
	pop r0
	rts
	WinP2:
		call ClearScreen
		loadn r0, #575
		loadn r1, #MSGP2
		loadn r2, #57344
		call PrintStr
		call WaitAnyKey
		loadn r0, #1
		store PONGOVER, r0
		pop r0
		rts

ResetBallRight:
	push r0
	loadn r0, #20
	store BX, r0
	loadn r0, #15
	store BY, r0
	loadn r0, #0
	store VX, r0
	store VY, r0
	pop r0
	rts

ResetBallLeft:
	push r0
	loadn r0, #20
	store BX, r0
	loadn r0, #15
	store BY, r0
	loadn r0, #1
	store VX, r0
	loadn r0, #0
	store VY, r0
	pop r0
	rts

PongDelay:
	push r0
	push r1
	push r2
	loadn r2, #6
	PDOut:
		loadn r0, #0
		loadn r1, #60000
		PDIn:
			inc r0
			cmp r0, r1
			jle PDIn
		dec r2
		loadn r1, #0
		cmp r2, r1
		jgr PDOut
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
; ======================  ROTINAS COMPARTILHADAS  =====================
; =====================================================================
WaitAnyKey:
	push r0
	push r1
	loadn r1, #255
	WAK1:
		inchar r0
		cmp r0, r1
		jeq WAK1
	WAK2:
		inchar r0
		cmp r0, r1
		jne WAK2
	pop r1
	pop r0
	rts

SmallDelay:
	push r0
	loadn r0, #30000
	SDLoop:
		dec r0
		jnz SDLoop
	pop r0
	rts

ClearScreen:
	push r0
	push r1
	push r2
	loadn r0, #0
	loadn r1, #1200
	loadn r2, #' '
	CSLoop:
		outchar r2, r0
		inc r0
		cmp r0, r1
		jle CSLoop
	pop r2
	pop r1
	pop r0
	rts

PrintStr:
	push r0
	push r1
	push r2
	push r3
	push r4
	loadn r3, #'\0'
	PSLoop:
		loadi r4, r1
		cmp r4, r3
		jeq PSDone
		add r4, r4, r2
		outchar r4, r0
		inc r0
		inc r1
		jmp PSLoop
	PSDone:
		pop r4
		pop r3
		pop r2
		pop r1
		pop r0
	rts

; =====================================================================
; ==============================  DADOS  ==============================
; =====================================================================
; --- Estado do terminal ---
CURX:   var #1
BUFLEN: var #1
BUF:    var #32

; --- Estado do jogo de digitacao ---
IDX:   var #1
SEC:   var #1
SUBT:  var #1
LASTK: var #1
LEN:   var #1

; --- Estado do Pong ---
P1Y:      var #1
P2Y:      var #1
BX:       var #1
BY:       var #1
VX:       var #1
VY:       var #1
SC1:      var #1
SC2:      var #1
PONGOVER: var #1

; --- Textos do terminal ---
BANNER1: string "*** ICMC-OS : TERMINAL ***"
BANNER2: string "Comandos: HELP CLEAR PONG DIGITAR SAIR"
PROMPT:  string "> "
HELP1:   string "HELP    - mostra esta ajuda"
HELP2:   string "CLEAR   - limpa a tela"
HELP3:   string "PONG    - Pong 2 jogadores W/S e I/K, Q sai"
HELP4:   string "DIGITAR - jogo de digitacao"
HELP5:   string "SAIR    - encerra o terminal"
MSGINV:  string "Comando invalido. Digite HELP."

CMD_HELP:  string "HELP"
CMD_CLEAR: string "CLEAR"
CMD_PONG:  string "PONG"
CMD_DIG:   string "DIGITAR"
CMD_SAIR:  string "SAIR"

; --- Textos do jogo de digitacao ---
TITULO:   string "JOGO DE DIGITACAO"
LBLTEMPO: string "TEMPO:"
LBLINSTR: string "DIGITE O TEXTO ABAIXO (MAIUSCULAS):"
TEXTO:    string "O RATO ROEU A ROUPA DO REI DE ROMA"
LBLFIM:   string "CONCLUIDO! VEJA SEU TEMPO ACIMA."

; --- Textos do Pong ---
MSGP1: string "JOGADOR 1 VENCEU!"
MSGP2: string "JOGADOR 2 VENCEU!"
