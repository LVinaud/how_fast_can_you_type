jmp main

; =====================================================================
;  HOW FAST CAN YOU TYPE  -  versao 2 (usa as instrucoes novas do processador)
;  Mudancas em relacao a versao original:
;   * SORTEIO DA FRASE: antes usava uma tabela fixa de numeros (Rand) +
;     IncRand. Agora usa a instrucao RAND, que le um contador de hardware.
;   * CONTADOR DE TEMPO: antes era "simulado" contando frames. Agora usa a
;     instrucao RDTIME, que devolve o tempo REAL em milissegundos.
;  O resto do jogo (comparacao, cores, backspace, impressao) esta igual.
; =====================================================================

; Cores - constantes globais
CorErro: var #1 ; 2
CorAcerto: var #1 ; 1
CorNeutra: var #1 ; 0

; Estado tecla pressionada para controlar velocidade de digitação
TeclaPressionada: var #1

; Controle de rounds usando tempo REAL (RDTIME)
ProxRound: var #1     ; proximo instante (em segundos) de trocar a frase

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
    ; primeiro round troca de frase quando o tempo passar de 10 segundos
    loadn r1, #10
    store ProxRound, r1
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

        ; ===== CONTADOR DE TEMPO REAL (usando RDTIME) =====
        rdtime r5                ; r5 <- tempo em milissegundos desde que ligou
        loadn r6, #1000
        div r5, r5, r6           ; r5 <- segundos totais

        ; --- troca de frase quando o tempo passa de ProxRound segundos ---
        load r4, ProxRound
        cmp r5, r4
        jle ImprimeTempo         ; ainda nao chegou no proximo round

        ; chegou: agenda o proximo round (+10 s) e sorteia outra frase
        loadn r6, #10
        add r4, r4, r6
        store ProxRound, r4
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

        ImprimeTempo:
        rdtime r5                ; le o tempo de novo
        loadn r6, #1000
        div r5, r5, r6           ; segundos totais
        loadn r6, #10
        div r4, r5, r6           ; dezena bruta = segundos / 10
        loadn r6, #10
        mod r4, r4, r6           ; mostrador da dezena fica entre 0 e 9
        loadn r6, #'0'
        add r4, r4, r6           ; vira digito ASCII
        loadn r0, #200           ; posicao na tela (dezena)
        outchar r4, r0
        loadn r6, #10
        mod r5, r5, r6           ; unidade = segundos % 10
        loadn r6, #'0'
        add r5, r5, r6
        loadn r0, #201           ; posicao na tela (unidade)
        outchar r5, r0
        ; ==================================================

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

    ; ---- AQUI ESTA A NOVA INSTRUCAO: RAND ----
    ; Antes: liamos um numero de uma tabela fixa (Rand + IncRand).
    ; Agora: pedimos um numero aleatorio ao hardware e tiramos o resto por 8.
    rand r3           ; r3 <- numero aleatorio do processador
    loadn r1, #8
    mod r3, r3, r1    ; r3 <- 0..7
    inc r3            ; r3 <- 1..8 (numero da frase que vamos pegar)

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
