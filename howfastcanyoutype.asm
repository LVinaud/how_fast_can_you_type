jmp main

; Cores - constantes globais
CorErro: var #1 ; 2
CorAcerto: var #1 ; 1 
CorNeutra: var #1 ; 0

; Estado tecla pressionada para controlar velocidade de digitação
TeclaPressionada: var #1

; Contador de tempo (simulado) e controle de rounds
FrameCont: var #1     ; conta iteracoes do loop
TempoUni: var #1      ; digito das unidades (0-9)
TempoDez: var #1      ; digito das dezenas (0-9)

; Buffer de input
UserInput: string "------------------------------------------------------------------------------------------------------------------------"
; Buffer
FraseEscolhida: var #120

; Mascara
Mascara: var #120

; Mensagens que serao impressas na tela
; tem que estar na forma: "/msg1/msg2/msg3"
; pode ter no max 8 msg
Frases: string "/po, faz esse esforco para a gente ai, ate quinta feira, que ai nao precisa nem ter bicho, entende, pra ganhar o jogo/se a gente nao ganhar do csa pelo amor de deus ne?/fala zeze, bom dia cara. deixa eu te falar uma coisa/e uma motivacao a mais pra gente cara, acertar o salario ai/ai voce nao precisa arrumar uma premiacao para ganhar o jogo, porque a nossa obrigacao e ganhar esse jogo! ta louco!"

; TABELA NUMEROS ALEATORIOS
IncRand: var #1			; Incremento para circular na Tabela de nr. Randomicos
Rand : var #30			; Tabela de nr. Randomicos entre 1 - 8
	static Rand + #0, #1
	static Rand + #1, #4
	static Rand + #2, #8
	static Rand + #3, #2
	static Rand + #4, #7
	static Rand + #5, #3
	static Rand + #6, #8
	static Rand + #7, #3
	static Rand + #8, #1
	static Rand + #9, #6
	static Rand + #10, #8
	static Rand + #11, #3
	static Rand + #12, #1
	static Rand + #13, #3
	static Rand + #14, #8
	static Rand + #15, #6
	static Rand + #16, #6
	static Rand + #17, #7
	static Rand + #18, #8
	static Rand + #19, #3
	static Rand + #20, #1
	static Rand + #20, #8
	static Rand + #21, #2
	static Rand + #22, #6
	static Rand + #23, #7
	static Rand + #24, #7
	static Rand + #25, #8
	static Rand + #26, #1
	static Rand + #27, #4
	static Rand + #28, #2
	static Rand + #29, #2


main:
    ; define valores das constantes de cores
    loadn r1, #0
    store TeclaPressionada, r1
    loadn r1, #116480
    store CorAcerto, r1
    loadn r1, #6912
    store CorErro, r1
    loadn r1, #0
    store CorNeutra, r1
    loadn r7, #UserInput ; r7 agora guarda o ponteiro para o caracter atual do userInput
    call SorteioFrase ; Frase aleatória escolhida e armazenada em FraseEscolhida
    ; init contador de tempo
    loadn r1, #0
    store FrameCont, r1
    store TempoUni, r1
    store TempoDez, r1
    loop:
        inchar r1 ; r1 agora guarda o caracter de input
        loadn r3, #255 ; 255 é o valor do input quando nada é digitado
        cmp r1, r3 ; se não for igual, algo foi digitado
        jeq NaoDigitou
        call DigitouAlgo ; Armazena caracter em UserInput
        jmp Digitou
        NaoDigitou:
        ;Muda o estado para nao pressionada
        loadn r6, #0
        loadn r5, #TeclaPressionada
        storei r5, r6
        Digitou:
        loadn r1, #FraseEscolhida
        loadn r2, #UserInput
        loadn r3, #Mascara
        call ComparaStr
        loadn r0, #0		; Posicao na tela onde a fraseEscolhida
        loadn r1, #FraseEscolhida		; Carrega r1 com o endereco do vetor que contem a fraseEscolhida
        loadn r2, #Mascara	    ; Seleciona a MASCARA da Mensagem
        call ImprimeStr

        ; ===== CONTADOR DE TEMPO / ROUNDS =====
        load r5, FrameCont
        inc r5
        store FrameCont, r5
        loadn r6, #2000          ; frames por "segundo" (ajustavel)
        cmp r5, r6
        jne ImprimeTempo         ; ainda nao completou 1 segundo

        loadn r5, #0             ; completou: zera os frames
        store FrameCont, r5

        load r4, TempoUni
        inc r4
        loadn r6, #10
        cmp r4, r6
        jne SalvaUni             ; nao estourou as unidades

        ; estourou unidades (a cada 10s) -> sobe dezena e faz novo round
        loadn r4, #0
        store TempoUni, r4
        load r5, TempoDez
        inc r5
        loadn r6, #10
        cmp r5, r6
        jne SalvaDez
        loadn r5, #0             ; dezena ciclica 0-9 (mostrador 00-99)
        SalvaDez:
        store TempoDez, r5

        ; --- novo round: anda na tabela Rand e sorteia outra frase ---
        load r5, IncRand
        inc r5
        store IncRand, r5
        call SorteioFrase
        ; reseta o buffer de input para tracos
        loadn r0, #UserInput
        loadn r1, #0
        loadn r2, #120
        loadn r3, #'-'
        ResetBuf:
            cmp r1, r2
            jeq FimResetBuf
            storei r0, r3
            inc r0
            inc r1
            jmp ResetBuf
        FimResetBuf:
        loadn r7, #UserInput     ; ponteiro de escrita volta ao inicio
        jmp ImprimeTempo

        SalvaUni:
        store TempoUni, r4

        ImprimeTempo:
        load r4, TempoDez        ; imprime dezena
        loadn r6, #'0'
        add r4, r4, r6
        loadn r0, #200           ; posicao na tela (ajustavel)
        outchar r4, r0
        load r4, TempoUni        ; imprime unidade
        loadn r6, #'0'
        add r4, r4, r6
        loadn r0, #201
        outchar r4, r0
        ; ======================================

    jmp loop
    
;********************************************************
;                   DIGITOU ALGO
;********************************************************
DigitouAlgo:
  push fr; Protege o registrador de flags
	push r0	; protege o r0 na pilha para preservar seu valor
	push r1	; protege o r1 na pilha para preservar seu valor
	push r2	; protege o r1 na pilha para preservar seu valor
	push r3	; protege o r3 na pilha para ser usado na subrotina
	push r4	; protege o r4 na pilha para ser usado na subrotina
  push r5	; protege o r3 na pilha para ser usado na subrotina
	push r6	; protege o r4 na pilha para ser usado na subrotina

  ;verifico se estava pressionada
  loadn r6, #TeclaPressionada
  loadi r5, r6
  loadn r6, #1
  cmp r5, r6
  jeq DigitouAlgo_Fim

  ;Muda o estado para pressionada
  loadn r6, #1
  loadn r5, #TeclaPressionada
  storei r5, r6

  loadn r5, #0 ; variavel incrementadora para o loop
  loadn r4, #8 ;codigo ascii de basckspace
  cmp r4, r1 ; se forem iguais, preciso decrementar r7
  jne Continua
  ; aqui preciso verificar se r7 ja não é igual a #UserInput, se for, não posso decrementar
  loadn r2, #UserInput
  cmp r2, r7
  jeq NaoDecrementa
  dec r7 ; decremento r7, ou seja o ponteiro do caractere atual
  NaoDecrementa:
  loadn r4, #'-' ;anoto o fim da string
  storei r7, r4 
  jmp DigitouAlgo_Fim
  Continua:
  ; preciso verificar se estou com r7 = #UserInput + 119, se for nao posso incrementar nem modificar o caracter
  loadn r2, #UserInput
  loadn r6, #119
  add r2, r2, r6
  cmp r2, r7
  jeq DigitouAlgo_Fim

  storei r7, r1 ; guarda o input no caracter atual do userInput
  inc r7 ; incrementa o caracter atual do UserInput
  DigitouAlgo_Fim:
  pop r6	
  pop r5
  pop r4	; Resgata os valores dos registradores utilizados na Subrotina da Pilha
  pop r3
  pop r2
  pop r1
  pop r0
  pop fr
  rts

;********************************************************
;                   SORTEIA FRASE
;********************************************************

SorteioFrase: ; vai salvar em FraseEscolhida a frase sorteada
    push fr; Protege o registrador de flags
	push r0	; protege o r0 na pilha para preservar seu valor
	push r1	; protege o r1 na pilha para preservar seu valor
	push r2	; protege o r1 na pilha para preservar seu valor
	push r3	; protege o r3 na pilha para ser usado na subrotina
	push r4	; protege o r4 na pilha para ser usado na subrotina
    push r5	; protege o r3 na pilha para ser usado na subrotina
	push r6	; protege o r4 na pilha para ser usado na subrotina
    push r7

    loadn r1, #Rand ; ponteiro para tabela de num aleatorios em r1
    load r2, IncRand ; incremento atual
    add r1, r1, r2 ; vai pro numero sorteado

    loadi r3, r1 ; r3 eh o numero sorteado

    ; vou ler r3 '/'s na minha Frases, e pego a string logo em sequencia
    ; salvo no buffer em FraseEscolhida
    
    loadn r0, #FraseEscolhida 
    loadn r1, #Frases
    loadn r4, #Frases ; salvar o endereco de inicio

    loadn r7, #'/' ; caracter pra comparacao
    loadn r6, #0 ; contador de barras
    loadn r5, #'\0' ; limite final

    SorteioFrase_loop:
        loadi r2, r1 ; r2 tem o char

        ; tenho que checar os limites
        cmp r2, r5
        jne SorteioFrase_comecaAlg ; se eu li diferente que vazio
        mov r1, r4 ; se eu li vazio
        jmp SorteioFrase_loop

        SorteioFrase_comecaAlg:
            cmp r2, r7 ; compara
            jeq SorteioFrase_incrementa ; se achou uma barra...

            inc r1
            jmp SorteioFrase_loop ; se nao, loopa

            SorteioFrase_incrementa:
                inc r6 ; inc qtd de barras
                cmp r6, r3 ; vamos ver se achamos a string
                jeq SorteioFrase_copiaString ; agora eh so copiar pro buffer

                inc r1
                jmp SorteioFrase_loop ; se ainda nao deu, volkta pro loop
    
    
    SorteioFrase_copiaString:
        ; r0 tá o inico do buffer
        ; r1 tá a posicao da barra
        inc r1 ; agora nao mais :)
        ; vou copiando até uma barra(r7) ou até \0(r5)

        loadi r2, r1; movo valor pra r2

        cmp r2, r7
        jeq SorteioFrase_fim
        cmp r2, r5
        jeq SorteioFrase_fim

        storei r0, r2; escrevo no buffer
        inc r0

        jmp SorteioFrase_copiaString ; chamo loop

    SorteioFrase_fim:
        pop r7
        pop r6
        pop r5
        pop r4	; Resgata os valores dos registradores utilizados na Subrotina da Pilha
        pop r3
        pop r2
        pop r1
        pop r0
        pop fr
        rts



;********************************************************
;                   COMPARA STRING
;********************************************************
ComparaStr: ; Função para comparar duas strings e preencher a mascara de cor a ser printada. r1 = endereco onde comeca a frase alvo, r2 = endereco onde comeca a frase escrita, r3 = endereco onde comeca a mascara
    push fr		; Protege o registrador de flags
	push r0	; protege o r0 na pilha para preservar seu valor
	push r1	; protege o r1 na pilha para preservar seu valor
	push r2	; protege o r2 na pilha para preservar seu valor
	push r3	; protege o r3 na pilha para ser usado na subrotina
	push r4	; protege o r4 na pilha para ser usado na subrotina
    push r5	; protege o r5 na pilha para ser usado na subrotina
	push r6	; protege o r6 na pilha para ser usado na subrotina 
    push r7 ; protege o r7 na pilha para ser usado na subrotina
  loadn r4, #'\0'	; Criterio de parada
  ComparaStr_Loop:
  	loadi r5, r1 ; r5 pega o caractere atual da string alvo
    loadi r6, r2 ; r6 pega o caractere atual da string digitada
	cmp r5, r4 ; compara se é igual a \0
    jeq ComparaStr_sai
    cmp r5, r6 ; aqui eu comparo se o caractere é igual na string digitada e na string alvo
    jeq AplicaIgual ; Vou escrever 1 na máscara, porque deu certo
    loadn r7, #'-' ; Não deu certo, então vou ver se é porque ainda nao digitei, ou seja a string aqui é um -
    cmp r6, r7 ; Se der igual, cor neutra porque ainda não digitei, se não, aplica erro
    jeq AplicaNeutro
    jmp AplicaErro
    AplicaErro:
      loadn r7, #'2'; Guardo 2 na máscara, quer dizer que deu erro e deve ser colorido de vermelho
      storei r3, r7 
      jmp Incrementa_Ponteiros ; Vou incrementar os 3 ponteiros
    AplicaNeutro:
      loadn r7, #'0' ; Quer dizer que ainda nem digitei, então vai printar em branco normal
      storei r3, r7
      jmp Incrementa_Ponteiros ; Vou incrementar os 3 ponteiros
    AplicaIgual:
      loadn r7, #'1' ; Quer dizer que deu certo, então coloco 1 na mascara que vai printar verde
      storei r3, r7
      jmp Incrementa_Ponteiros ; Vou incrementar os 3 ponteiros
    Incrementa_Ponteiros:
      inc r1
      inc r2
      inc r3
      jmp ComparaStr_Loop
    ComparaStr_sai:
      pop r7
      pop r6
      pop r5
      pop r4	; Resgata os valores dos registradores utilizados na Subrotina da Pilha
      pop r3
      pop r2
      pop r1
      pop r0
      pop fr
      rts
;********************************************************
;                   IMPRIME STRING
;********************************************************
	
ImprimeStr:	;  Rotina de Impresao de Mensagens:    r0 = Posicao da tela que o primeiro caractere da mensagem sera' impresso;  r1 = endereco onde comeca a mensagem; r2 = MASCARA da mensagem.   Obs: a mensagem sera' impressa ate' encontrar "/0"
	push fr		; Protege o registrador de flags
	push r0	; protege o r0 na pilha para preservar seu valor
	push r1	; protege o r1 na pilha para preservar seu valor
	push r2	; protege o r1 na pilha para preservar seu valor
	push r3	; protege o r3 na pilha para ser usado na subrotina
	push r4	; protege o r4 na pilha para ser usado na subrotina
  push r5	; protege o r3 na pilha para ser usado na subrotina
	push r6	; protege o r4 na pilha para ser usado na subrotina
  push r7
	
	loadn r3, #'\0'	; Criterio de parada

   ImprimeStr_Loop:	
		loadi r4, r1 ; r4 pega o caractere atual
		cmp r4, r3 ; compara se é igual a \0
		jeq ImprimeStr_Sai

        loadi r5, r2 ; r5 guarda o valor (char 0 - CorNeutra; 1 - CorAcerto; 2 - CorErro)
        
        loadn r6, #'0'

        cmp r5, r6 
        jeq AplicaCorNeutra

        loadn r6, #'1'

        cmp r5, r6
        jeq AplicaCorAcerto

        loadn r6, #'2'

        cmp r5, r6  
        jeq AplicaCorErro

    AplicaCorNeutra:
        load r6, CorNeutra ; o 256 é a cor, mude o 256 para a cor
        add r4, r6, r4 ; aplica
        jmp AcabouCor
    
    AplicaCorAcerto:
        load r6, CorAcerto
        add r4, r6, r4 ; aplica
        jmp AcabouCor
    
    AplicaCorErro:
        load r6, CorErro
        add r4, r6, r4 ; aplica
        jmp AcabouCor


    AcabouCor:
        outchar r4, r0
        inc r0
        inc r1
        inc r2
        jmp ImprimeStr_Loop
	
   ImprimeStr_Sai:
    pop r7
    pop r6
    pop r5
		pop r4	; Resgata os valores dos registradores utilizados na Subrotina da Pilha
		pop r3
		pop r2
		pop r1
		pop r0
		pop fr
	rts