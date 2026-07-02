; =====================================================================
;  PONG  -  2 jogadores  -  Processador ICMC (tela 40x30, teclado)
; ---------------------------------------------------------------------
;  Jogador 1 (raquete esquerda, verde):  W = sobe   S = desce
;  Jogador 2 (raquete direita,  vermelha): I = sobe  K = desce
;  A bola (amarela) quica nas paredes de cima/baixo e nas raquetes.
;  Quem deixar a bola passar da sua raquete dá ponto ao adversario.
;  Primeiro a chegar em 5 pontos vence.
;
;  OBS: o ICMC lê uma tecla por vez (INCHAR), logo apenas um jogador
;  move por quadro. É uma limitacao do hardware, nao do jogo.
;
;  Tela: posicao = linha*40 + coluna  (linhas 0..29, colunas 0..39)
;  Cor  : ASCII + offset R3G3B2 nos bits altos (ver README RGB8)
;         verde=7168  vermelho=57344  amarelo=64512
;  Chars ja com cor:  raquete1='#'+verde=7203  raquete2='#'+verm=57379
;                     bola='O'+amarelo=64591
; =====================================================================

; ---- Programa principal (comeca no endereco 0) ----
main:
	call Init

	GameLoop:
		call ReadInput      ; le teclado e move uma raquete
		call MoveBall       ; move a bola, trata colisoes e pontos
		call Delay          ; controla a velocidade do jogo
		jmp GameLoop

; =====================================================================
;  Init - limpa a tela, desenha a rede, zera variaveis e desenha tudo
; =====================================================================
Init:
	push r0
	push r1
	push r2

	; --- Limpa a tela inteira (1200 posicoes) com espaco ---
	loadn r0, #0            ; posicao atual
	loadn r1, #1200         ; total de posicoes
	loadn r2, #' '
	ClearLoop:
		outchar r2, r0
		inc r0
		cmp r0, r1
		jle ClearLoop

	; --- Rede central pontilhada (coluna 20, linhas 2..27) ---
	loadn r0, #100         ; pos = 2*40 + 20
	loadn r1, #1100        ; pos = 27*40 + 20
	loadn r2, #':'
	loadn r3, #40
	NetLoop:
		outchar r2, r0
		add r0, r0, r3
		cmp r0, r1
		jle NetLoop

	; --- Estado inicial das variaveis ---
	loadn r0, #12
	store P1Y, r0          ; raquete 1 nas linhas 12..15
	store P2Y, r0          ; raquete 2 nas linhas 12..15
	loadn r0, #20
	store BX, r0           ; bola no centro
	loadn r0, #15
	store BY, r0
	loadn r0, #0
	store VX, r0           ; VX: 0=direita, 1=esquerda
	loadn r0, #1
	store VY, r0           ; VY: 0=baixo,   1=cima
	loadn r0, #0
	store SC1, r0
	store SC2, r0

	; --- Desenha raquetes, bola e placar ---
	call DrawP1Full
	call DrawP2Full
	call DrawScore
	load r0, BY
	load r1, BX
	loadn r2, #64591
	call DrawCell

	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
;  DrawCell - escreve r2 (char) na posicao (linha r0, coluna r1)
;             Preserva r0, r1, r2 (so consome r3 internamente).
; =====================================================================
DrawCell:
	push r0
	push r3
	loadn r3, #40
	mul r0, r0, r3         ; r0 = linha * 40
	add r0, r0, r1         ; r0 = linha*40 + coluna = posicao
	outchar r2, r0         ; escreve o caractere
	pop r3
	pop r0
	rts

; =====================================================================
;  DrawP1Full / DrawP2Full - desenha a raquete inteira (4 celulas)
; =====================================================================
DrawP1Full:
	push r0
	push r1
	push r2
	push r3
	push r4
	load r0, P1Y           ; linha do topo
	loadn r3, #4           ; altura
	loadn r4, #0
	P1FLoop:
		loadn r1, #1       ; coluna 1
		loadn r2, #7203    ; '#' verde
		call DrawCell
		inc r0
		inc r4
		cmp r4, r3
		jle P1FLoop
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
	P2FLoop:
		loadn r1, #38      ; coluna 38
		loadn r2, #57379   ; '#' vermelho
		call DrawCell
		inc r0
		inc r4
		cmp r4, r3
		jle P2FLoop
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
;  DrawScore - imprime os placares (0..9) no topo da tela
; =====================================================================
DrawScore:
	push r0
	push r1
	load r0, SC1
	loadn r1, #48          ; '0'
	add r0, r0, r1
	loadn r1, #5           ; linha 0, coluna 5
	outchar r0, r1
	load r0, SC2
	loadn r1, #48
	add r0, r0, r1
	loadn r1, #34          ; linha 0, coluna 34
	outchar r0, r1
	pop r1
	pop r0
	rts

; =====================================================================
;  ReadInput - le uma tecla e move a raquete correspondente em 1 linha.
;  Ao mover, apaga a celula que a raquete deixa e desenha a nova ponta.
; =====================================================================
ReadInput:
	push r0
	push r1
	push r2

	inchar r0

	loadn r1, #119         ; 'w' -> P1 sobe
	cmp r0, r1
	jeq P1Up
	loadn r1, #115         ; 's' -> P1 desce
	cmp r0, r1
	jeq P1Down
	loadn r1, #105         ; 'i' -> P2 sobe
	cmp r0, r1
	jeq P2Up
	loadn r1, #107         ; 'k' -> P2 desce
	cmp r0, r1
	jeq P2Down
	jmp RIEnd

	; ---- Jogador 1 sobe ----
	P1Up:
		load r0, P1Y
		loadn r1, #1
		cmp r0, r1
		jle RIEnd          ; ja no topo (P1Y <= 1): nao move
		jeq RIEnd
		loadn r1, #3       ; apaga a celula de baixo (P1Y+3)
		add r0, r0, r1
		loadn r1, #1
		loadn r2, #' '
		call DrawCell
		load r0, P1Y
		dec r0
		store P1Y, r0      ; sobe a raquete
		loadn r1, #1       ; desenha a nova celula de cima (P1Y)
		loadn r2, #7203
		call DrawCell
		jmp RIEnd

	; ---- Jogador 1 desce ----
	P1Down:
		load r0, P1Y
		loadn r1, #25
		cmp r0, r1
		jeg RIEnd          ; ja embaixo (P1Y >= 25): nao move
		loadn r1, #1       ; apaga a celula de cima (P1Y)
		loadn r2, #' '
		call DrawCell
		load r0, P1Y
		inc r0
		store P1Y, r0      ; desce a raquete
		loadn r1, #3       ; desenha a nova celula de baixo (P1Y+3)
		add r0, r0, r1
		loadn r1, #1
		loadn r2, #7203
		call DrawCell
		jmp RIEnd

	; ---- Jogador 2 sobe ----
	P2Up:
		load r0, P2Y
		loadn r1, #1
		cmp r0, r1
		jle RIEnd
		jeq RIEnd
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
		jmp RIEnd

	; ---- Jogador 2 desce ----
	P2Down:
		load r0, P2Y
		loadn r1, #25
		cmp r0, r1
		jeg RIEnd
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
		jmp RIEnd

	RIEnd:
		pop r2
		pop r1
		pop r0
		rts

; =====================================================================
;  MoveBall - apaga a bola, atualiza posicao, trata colisoes e pontos,
;             e redesenha a bola na nova posicao.
; =====================================================================
MoveBall:
	push r0
	push r1
	push r2

	; --- Apaga a bola na posicao antiga ---
	load r0, BY
	load r1, BX
	loadn r2, #' '
	call DrawCell

	; --- Atualiza a linha (BY) conforme VY ---
	load r0, VY
	loadn r1, #0
	cmp r0, r1
	jeq BallDown           ; VY=0 -> desce
		load r0, BY        ; VY=1 -> sobe
		dec r0
		store BY, r0
		jmp BallXupd
	BallDown:
		load r0, BY
		inc r0
		store BY, r0
	BallXupd:

	; --- Atualiza a coluna (BX) conforme VX ---
	load r0, VX
	loadn r1, #0
	cmp r0, r1
	jeq BallRight          ; VX=0 -> direita
		load r0, BX        ; VX=1 -> esquerda
		dec r0
		store BX, r0
		jmp BallWalls
	BallRight:
		load r0, BX
		inc r0
		store BX, r0
	BallWalls:

	; --- Parede de cima (linha 1) ---
	load r0, BY
	loadn r1, #1
	cmp r0, r1
	jgr ChkBottom
		loadn r0, #1
		store BY, r0
		loadn r0, #0       ; passa a descer
		store VY, r0
	ChkBottom:
	; --- Parede de baixo (linha 28) ---
	load r0, BY
	loadn r1, #28
	cmp r0, r1
	jle ChkLeft
		loadn r0, #28
		store BY, r0
		loadn r0, #1       ; passa a subir
		store VY, r0
	ChkLeft:

	; --- Raquete esquerda (coluna 2) / ponto do Jogador 2 ---
	load r0, BX
	loadn r1, #2
	cmp r0, r1
	jne ChkScoreL          ; so testa a raquete quando BX == 2
		load r0, BY
		load r1, P1Y
		cmp r0, r1
		jle ChkScoreL      ; BY < topo da raquete -> nao rebateu
		loadn r2, #3
		add r1, r1, r2     ; r1 = P1Y + 3 (base da raquete)
		cmp r0, r1
		jgr ChkScoreL      ; BY > base -> nao rebateu
		loadn r0, #0       ; rebateu: passa a ir para a direita
		store VX, r0
		jmp BallDraw
	ChkScoreL:
	load r0, BX
	loadn r1, #0
	cmp r0, r1
	jgr ChkRight           ; BX > 0 -> ainda em jogo
		call ScoreP2       ; bola saiu pela esquerda: ponto do J2
		jmp BallDraw
	ChkRight:

	; --- Raquete direita (coluna 37) / ponto do Jogador 1 ---
	load r0, BX
	loadn r1, #37
	cmp r0, r1
	jne ChkScoreR
		load r0, BY
		load r1, P2Y
		cmp r0, r1
		jle ChkScoreR
		loadn r2, #3
		add r1, r1, r2
		cmp r0, r1
		jgr ChkScoreR
		loadn r0, #1       ; rebateu: passa a ir para a esquerda
		store VX, r0
		jmp BallDraw
	ChkScoreR:
	load r0, BX
	loadn r1, #39
	cmp r0, r1
	jle BallDraw           ; BX < 39 -> ainda em jogo
		call ScoreP1       ; bola saiu pela direita: ponto do J1

	; --- Redesenha a bola na nova posicao ---
	BallDraw:
		load r0, BY
		load r1, BX
		loadn r2, #64591
		call DrawCell

	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
;  ScoreP1 / ScoreP2 - soma ponto, atualiza placar, checa vitoria e
;                      recoloca a bola no centro.
; =====================================================================
ScoreP1:
	push r0
	load r0, SC1
	inc r0
	store SC1, r0
	call DrawScore
	loadn r1, #5
	cmp r0, r1
	jeq WinP1              ; 5 pontos -> vitoria do J1
	call ResetBallRight   ; serve para a direita (J2 recebe)
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
	call ResetBallLeft    ; serve para a esquerda (J1 recebe)
	pop r0
	rts

ResetBallRight:
	push r0
	loadn r0, #20
	store BX, r0
	loadn r0, #15
	store BY, r0
	loadn r0, #0          ; VX=0 direita
	store VX, r0
	loadn r0, #0          ; VY=0 baixo
	store VY, r0
	pop r0
	rts

ResetBallLeft:
	push r0
	loadn r0, #20
	store BX, r0
	loadn r0, #15
	store BY, r0
	loadn r0, #1          ; VX=1 esquerda
	store VX, r0
	loadn r0, #0
	store VY, r0
	pop r0
	rts

; =====================================================================
;  Vitoria - limpa a tela, imprime a mensagem e para (HALT).
; =====================================================================
WinP1:
	call ClearScreen
	loadn r0, #575         ; centro aprox. (linha 14, coluna 15)
	loadn r1, #MsgP1
	loadn r2, #7168        ; verde
	call Imprime
	halt

WinP2:
	call ClearScreen
	loadn r0, #575
	loadn r1, #MsgP2
	loadn r2, #57344       ; vermelho
	call Imprime
	halt

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

; =====================================================================
;  Imprime - escreve a string (terminada em '\0') em r1 a partir da
;            posicao r0 na tela, somando a cor r2 a cada caractere.
;            (mesmo padrao usado no snake.asm da disciplina)
; =====================================================================
Imprime:
	push r0
	push r1
	push r2
	push r3
	push r4
	loadn r3, #'\0'
	LoopImprime:
		loadi r4, r1
		cmp r4, r3
		jeq SaiImprime
		add r4, r2, r4
		outchar r4, r0
		inc r0
		inc r1
		jmp LoopImprime
	SaiImprime:
		pop r4
		pop r3
		pop r2
		pop r1
		pop r0
	rts

; =====================================================================
;  Delay - laco de espera (ajuste os contadores para mudar a velocidade)
; =====================================================================
Delay:
	push r0
	push r1
	push r2
	loadn r2, #6           ; repeticoes externas
	DelayOut:
		loadn r0, #0
		loadn r1, #60000   ; contador interno
		DelayIn:
			inc r0
			cmp r0, r1
			jle DelayIn
		dec r2
		loadn r1, #0
		cmp r2, r1
		jgr DelayOut
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
;  Variaveis e mensagens (ficam depois do codigo, em enderecos altos)
; =====================================================================
P1Y:  var #1     ; linha do topo da raquete 1
P2Y:  var #1     ; linha do topo da raquete 2
BX:   var #1     ; coluna da bola
BY:   var #1     ; linha da bola
VX:   var #1     ; direcao horizontal (0=direita, 1=esquerda)
VY:   var #1     ; direcao vertical   (0=baixo,   1=cima)
SC1:  var #1     ; placar do jogador 1
SC2:  var #1     ; placar do jogador 2

MsgP1: string "JOGADOR 1 VENCEU!"
MsgP2: string "JOGADOR 2 VENCEU!"
