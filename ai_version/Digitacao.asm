; =====================================================================
;  JOGO DE DIGITACAO  -  Processador ICMC (tela 40x30)
; ---------------------------------------------------------------------
;  O jogador deve digitar o texto pre-definido exibido na tela.
;   - Letra ainda NAO digitada: BRANCA
;   - Letra digitada CORRETA:   VERDE
;   - Letra digitada ERRADA:    VERMELHA
;  Um contador de TEMPO (em segundos) mostra quao rapido o jogador digita.
;
;  OBS: o teclado do ICMC devolve MAIUSCULAS (A=65). O texto usa
;  maiusculas e espacos para casar com o que a tecla envia.
;  Cores (offset somado ao ASCII): branco=0  verde=7168  vermelho=57344
; =====================================================================

main:
	call RunTyping
	halt

; =====================================================================
;  RunTyping - roda o jogo inteiro e retorna (rts) ao terminar.
;  E' uma subrotina para poder ser chamada tambem pelo "S.O." (SO.asm).
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

	; --- Cabecalho e textos fixos ---
	loadn r0, #0            ; titulo (linha 0)
	loadn r1, #TITULO
	loadn r2, #64512       ; amarelo
	call PrintStr

	loadn r0, #80          ; rotulo "TEMPO:" (linha 2)
	loadn r1, #LBLTEMPO
	loadn r2, #0
	call PrintStr

	loadn r0, #160         ; instrucao (linha 4)
	loadn r1, #LBLINSTR
	loadn r2, #0
	call PrintStr

	loadn r0, #240         ; o TEXTO a digitar, em branco (linha 6)
	loadn r1, #TEXTO
	loadn r2, #0
	call PrintStr

	; --- Calcula o tamanho do texto e zera o estado ---
	call CalcLen
	loadn r0, #0
	store IDX, r0
	store SEC, r0
	store SUBT, r0
	loadn r0, #255
	store LASTK, r0
	call ShowTime

	; --- Laco principal: poll do teclado + relogio ---
	TLoop:
		inchar r0
		loadn r1, #255
		cmp r0, r1
		jeq TNoKey             ; nenhuma tecla

		load r1, LASTK
		cmp r0, r1
		jeq TTick              ; mesma tecla ainda segurada -> ignora

		store LASTK, r0        ; registra a nova tecla
		loadn r1, #32
		cmp r0, r1
		jle TTick              ; tecla de controle (<32) -> ignora

		call ProcessKey        ; compara com o esperado e colore

		load r1, IDX
		load r2, LEN
		cmp r1, r2
		jeq TFinish            ; acabou o texto
		jmp TTick

	TNoKey:
		loadn r0, #255
		store LASTK, r0        ; tecla solta -> permite repetir a mesma

	TTick:
		call SmallDelay        ; passo de tempo (~10 ms na placa)
		load r0, SUBT
		inc r0
		loadn r1, #100         ; 100 passos ~ 1 segundo
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
		loadn r0, #480         ; mensagem final (linha 12)
		loadn r1, #LBLFIM
		loadn r2, #7168        ; verde
		call PrintStr
		call WaitAnyKey        ; espera uma tecla antes de sair

	pop r7
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	rts

; =====================================================================
;  ProcessKey - r0 = tecla digitada. Compara com TEXTO[IDX], pinta a
;  letra de verde (acerto) ou vermelho (erro) e avanca o indice.
; =====================================================================
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
	loadi r4, r2           ; r4 = caractere esperado
	loadn r5, #240         ; base do texto na tela
	add r5, r5, r3         ; posicao da letra atual
	cmp r0, r4
	jeq PKCorrect
		loadn r6, #57344   ; ERRO -> vermelho
		add r4, r4, r6
		outchar r4, r5
		jmp PKAdv
	PKCorrect:
		loadn r6, #7168    ; ACERTO -> verde
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

; =====================================================================
;  CalcLen - conta os caracteres de TEXTO ate' o '\0' e guarda em LEN.
; =====================================================================
CalcLen:
	push r0
	push r1
	push r2
	push r3
	loadn r0, #TEXTO
	loadn r1, #0           ; contador
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

; =====================================================================
;  ShowTime - imprime SEC (3 digitos) na posicao 87 (ao lado de TEMPO:)
; =====================================================================
ShowTime:
	push r0
	push r1
	push r2
	push r3
	push r4
	load r0, SEC
	loadn r1, #100
	div r2, r0, r1         ; centena
	mod r0, r0, r1         ; resto (0..99)
	loadn r1, #10
	div r3, r0, r1         ; dezena
	mod r4, r0, r1         ; unidade
	loadn r0, #48          ; '0'
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
;  WaitAnyKey - espera uma tecla ser pressionada e depois solta.
; =====================================================================
WaitAnyKey:
	push r0
	push r1
	loadn r1, #255
	WAK1:
		inchar r0
		cmp r0, r1
		jeq WAK1               ; espera pressionar
	WAK2:
		inchar r0
		cmp r0, r1
		jne WAK2               ; espera soltar
	pop r1
	pop r0
	rts

; =====================================================================
;  SmallDelay - passo de tempo. Ajuste #30000 para calibrar o relogio
;  (na placa RGB8 de 12 MHz, ~10 ms; 100 passos ~ 1 segundo).
; =====================================================================
SmallDelay:
	push r0
	loadn r0, #30000
	SDLoop:
		dec r0
		jnz SDLoop
	pop r0
	rts

; =====================================================================
;  ClearScreen - preenche as 1200 posicoes da tela com espaco.
; =====================================================================
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
;  PrintStr - imprime a string (terminada em '\0') apontada por r1 a
;  partir da posicao r0, somando a cor r2 a cada caractere.
; =====================================================================
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
;  Variaveis e textos (enderecos altos, depois do codigo)
; =====================================================================
IDX:   var #1     ; indice do proximo caractere a digitar
SEC:   var #1     ; segundos decorridos
SUBT:  var #1     ; sub-contador de tempo (0..99)
LASTK: var #1     ; ultima tecla (deteccao de borda)
LEN:   var #1     ; tamanho do texto

TITULO:   string "JOGO DE DIGITACAO"
LBLTEMPO: string "TEMPO:"
LBLINSTR: string "DIGITE O TEXTO ABAIXO (MAIUSCULAS):"
TEXTO:    string "O RATO ROEU A ROUPA DO REI DE ROMA"
LBLFIM:   string "CONCLUIDO! VEJA SEU TEMPO ACIMA."
