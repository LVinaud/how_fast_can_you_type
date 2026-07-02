;================================================================
; SimOS — Sistema Operacional Minimalista para Processador ICMC
;================================================================
; O que existe:
;   * Shell interativo com prompt "> "
;   * Edicao de linha (BACKSPACE apaga, ENTER executa)
;   * Comandos built-in: help, clear, about, snake, colors
;   * Snake integrado como "app" (CALL/RTS, volta pro shell)
;   * Multitarefa cooperativa (cada app e' uma subrotina)
;
; O que NAO existe (impossivel sem mudar o hardware):
;   * Interrupcoes / timer -> sem preempcao
;   * MMU / modo privilegiado -> sem protecao
;   * Disco -> sem persistencia
;================================================================

;----------------------------------------------------------------
; BOOT — entra aqui em PC=0
;----------------------------------------------------------------
boot:
        call    kclear_screen
        call    show_banner
shell_loop:
        call    print_prompt
        call    read_line
        call    execute
        jmp     shell_loop

;----------------------------------------------------------------
; print_char  (r1 = char) — escreve no cursor, avanca, wrap
;   trata 10 (\n) como newline
;----------------------------------------------------------------
print_char:
        push    r0
        push    r2
        loadn   r2, #10
        cmp     r1, r2
        jeq     pc_newline
        load    r0, cursor
        outchar r1, r0
        inc     r0
        jmp     pc_check
pc_newline:
        push    r3
        load    r0, cursor
        loadn   r2, #40
        mod     r3, r0, r2
        sub     r3, r2, r3
        add     r0, r0, r3
        pop     r3
pc_check:
        loadn   r2, #1200
        cmp     r0, r2
        jle     pc_save
        loadn   r0, #0
pc_save:
        store   cursor, r0
        pop     r2
        pop     r0
        rts

;----------------------------------------------------------------
; print_str  (r0 = ptr) — imprime ate null
;----------------------------------------------------------------
print_str:
        push    r0
        push    r1
        push    r2
        loadn   r2, #0
ps_loop:
        loadi   r1, r0
        cmp     r1, r2
        jeq     ps_done
        call    print_char
        inc     r0
        jmp     ps_loop
ps_done:
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; kclear_screen — limpa tela toda e zera cursor
;----------------------------------------------------------------
kclear_screen:
        push    r0
        push    r1
        push    r2
        loadn   r0, #32
        loadn   r1, #0
        loadn   r2, #1200
kc_loop:
        outchar r0, r1
        inc     r1
        dec     r2
        jnz     kc_loop
        loadn   r0, #0
        store   cursor, r0
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; show_banner — desenha titulo no topo
;----------------------------------------------------------------
show_banner:
        push    r0
        loadn   r0, #str_banner
        call    print_str
        pop     r0
        rts

;----------------------------------------------------------------
; print_prompt — escreve "> "
;----------------------------------------------------------------
print_prompt:
        push    r0
        loadn   r0, #str_prompt
        call    print_str
        pop     r0
        rts

;----------------------------------------------------------------
; read_line — le teclado ate ENTER, escreve em cmd_buf
;   trata BACKSPACE (0x08), ENTER (0x0A)
;   debounce: espera tecla soltar antes da proxima
;----------------------------------------------------------------
read_line:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        loadn   r3, #cmd_buf
        loadn   r4, #cmd_buf
        loadn   r0, #63
        add     r4, r4, r0
rl_loop:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jeq     rl_loop
        loadn   r1, #10
        cmp     r0, r1
        jeq     rl_done
        loadn   r1, #13
        cmp     r0, r1
        jeq     rl_done
        loadn   r1, #8
        cmp     r0, r1
        jeq     rl_back
        loadn   r1, #127
        cmp     r0, r1
        jeq     rl_back
        cmp     r3, r4
        jeg     rl_release
        storei  r3, r0
        inc     r3
        mov     r1, r0
        call    print_char
rl_release:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     rl_release
        jmp     rl_loop
rl_back:
        loadn   r1, #cmd_buf
        cmp     r3, r1
        jeq     rl_back_rel
        dec     r3
        load    r0, cursor
        loadn   r1, #0
        cmp     r0, r1
        jeq     rl_back_rel
        dec     r0
        store   cursor, r0
        loadn   r1, #32
        call    print_char
        load    r0, cursor
        dec     r0
        store   cursor, r0
rl_back_rel:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     rl_back_rel
        jmp     rl_loop
rl_done:
        loadn   r0, #0
        storei  r3, r0
rl_enter_rel:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     rl_enter_rel
        loadn   r1, #10
        call    print_char
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; str_eq  (r0 = a, r1 = b) -> r5 = 1 se iguais, 0 senao
;----------------------------------------------------------------
str_eq:
        push    r0
        push    r1
        push    r2
        push    r3
se_loop:
        loadi   r2, r0
        loadi   r3, r1
        cmp     r2, r3
        jne     se_no
        loadn   r3, #0
        cmp     r2, r3
        jeq     se_yes
        inc     r0
        inc     r1
        jmp     se_loop
se_no:
        loadn   r5, #0
        jmp     se_done
se_yes:
        loadn   r5, #1
se_done:
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; execute — compara cmd_buf com tabela e despacha
;----------------------------------------------------------------
execute:
        push    r0
        push    r1
        push    r2
        push    r5
        loadn   r0, #cmd_buf
        loadi   r1, r0
        loadn   r2, #0
        cmp     r1, r2
        jeq     ex_done
        loadn   r0, #cmd_buf
        loadn   r1, #str_help_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_help
        loadn   r0, #cmd_buf
        loadn   r1, #str_clear_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_clear
        loadn   r0, #cmd_buf
        loadn   r1, #str_about_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_about
        loadn   r0, #cmd_buf
        loadn   r1, #str_colors_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_colors
        loadn   r0, #cmd_buf
        loadn   r1, #str_snake_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_snake
        loadn   r0, #cmd_buf
        loadn   r1, #str_tetris_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_tetris
        loadn   r0, #cmd_buf
        loadn   r1, #str_donut_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_donut
        loadn   r0, #cmd_buf
        loadn   r1, #str_invaders_cmd
        call    str_eq
        loadn   r2, #1
        cmp     r5, r2
        jeq     ex_invaders
        loadn   r0, #str_unknown
        call    print_str
        jmp     ex_done
ex_help:
        call    cmd_help
        jmp     ex_done
ex_clear:
        call    cmd_clear
        jmp     ex_done
ex_about:
        call    cmd_about
        jmp     ex_done
ex_colors:
        call    cmd_colors
        jmp     ex_done
ex_snake:
        call    cmd_snake
        jmp     ex_done
ex_tetris:
        call    cmd_tetris
        jmp     ex_done
ex_donut:
        call    cmd_donut
        jmp     ex_done
ex_invaders:
        call    cmd_invaders
        jmp     ex_done
ex_done:
        pop     r5
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; COMANDOS
;----------------------------------------------------------------
cmd_help:
        push    r0
        loadn   r0, #str_help_text
        call    print_str
        pop     r0
        rts

cmd_clear:
        call    kclear_screen
        call    show_banner
        rts

cmd_about:
        push    r0
        loadn   r0, #str_about_text
        call    print_str
        pop     r0
        rts

;----------------------------------------------------------------
; cmd_colors — printa 'X' em cada uma das 16 cores
;----------------------------------------------------------------
cmd_colors:
        push    r0
        push    r1
        push    r2
        loadn   r2, #0
co_loop:
        loadn   r0, #256
        mul     r0, r2, r0
        loadn   r1, #88
        add     r1, r1, r0
        call    print_char
        inc     r2
        loadn   r0, #16
        cmp     r2, r0
        jne     co_loop
        loadn   r1, #10
        call    print_char
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; cmd_snake — roda o snake e volta pro shell
;----------------------------------------------------------------
cmd_snake:
        call    s_clear_screen
        call    s_draw_border
        call    s_init_snake
        call    s_place_food
sn_loop:
        call    s_read_input
        call    s_advance_snake
        loadn   r0, #0
        cmp     r5, r0
        jeq     sn_dead
        call    s_delay
        jmp     sn_loop
sn_dead:
        call    s_show_game_over
        call    s_wait_any_key
        call    kclear_screen
        call    show_banner
        rts

;----------------------------------------------------------------
; s_wait_any_key — espera teclado ficar idle, depois espera tecla
;----------------------------------------------------------------
s_wait_any_key:
        push    r0
        push    r1
swk_idle:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     swk_idle
swk_press:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jeq     swk_press
swk_release:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     swk_release
        pop     r1
        pop     r0
        rts
; s_clear_screen — pinta toda a tela 40x30 com espaco
;================================================================
s_clear_screen:
        PUSH    R0
        PUSH    R1
        PUSH    R2
        LOADN   R0, #32                ; ' ' (ASCII 32 = espaco)
        LOADN   R1, #0                 ; pos 0
        LOADN   R2, #1200              ; 30*40 celulas
cs_loop:
        OUTCHAR R0, R1
        INC     R1
        DEC     R2
        JNZ     cs_loop
        POP     R2
        POP     R1
        POP     R0
        RTS

;================================================================
; s_draw_border — '#' verde nas 4 bordas
;================================================================
s_draw_border:
        PUSH    R0
        PUSH    R1
        PUSH    R2
        PUSH    R3
        PUSH    R4

        LOADN   R0, #547             ; cor 2 (verde) | '#' (codigo 3)

        ; linha 0 (top)
        LOADN   R1, #0
        LOADN   R2, #40
db_top:
        OUTCHAR R0, R1
        INC     R1
        DEC     R2
        JNZ     db_top

        ; linha 29 (bottom)
        LOADN   R1, #1160              ; 29 * 40
        LOADN   R2, #40
db_bot:
        OUTCHAR R0, R1
        INC     R1
        DEC     R2
        JNZ     db_bot

        ; colunas 0 e 39, linhas 1..28
        LOADN   R1, #40                ; comeca em (lin 1, col 0)
        LOADN   R2, #28                ; 28 linhas
        LOADN   R3, #39                ; offset coluna direita
db_sides:
        OUTCHAR R0, R1                 ; coluna esquerda
        ADD     R4, R1, R3             ; R4 = R1 + 39
        OUTCHAR R0, R4                 ; coluna direita
        LOADN   R4, #40
        ADD     R1, R1, R4             ; proxima linha
        DEC     R2
        JNZ     db_sides

        POP     R4
        POP     R3
        POP     R2
        POP     R1
        POP     R0
        RTS

;================================================================
; s_init_snake — coloca cobra inicial e variaveis de estado
;================================================================
s_init_snake:
        PUSH    R0
        PUSH    R1

        ; corpo inicial em (linha 15, col 18..20) => pos 618, 619, 620
        LOADN   R1, #snake_buf
        LOADN   R0, #618
        STOREI  R1, R0                 ; snake_buf[0] = 618 (cauda)
        INC     R1
        LOADN   R0, #619
        STOREI  R1, R0                 ; snake_buf[1] = 619 (meio)
        INC     R1
        LOADN   R0, #620
        STOREI  R1, R0                 ; snake_buf[2] = 620 (cabeca)

        LOADN   R0, #0
        STORE   tail_idx, R0
        LOADN   R0, #2
        STORE   head_idx, R0
        LOADN   R0, #3
        STORE   length, R0
        LOADN   R0, #1                 ; direcao = direita (+1)
        STORE   dir, R0
        LOADN   R0, #12345             ; semente do RNG
        STORE   seed, R0

        ; desenha corpo
        LOADN   R0, #591             ; 'O' verde
        LOADN   R1, #618
        OUTCHAR R0, R1
        LOADN   R1, #619
        OUTCHAR R0, R1
        ; desenha cabeca
        LOADN   R0, #2880             ; '@' amarelo
        LOADN   R1, #620
        OUTCHAR R0, R1

        POP     R1
        POP     R0
        RTS

;================================================================
; s_read_input — le tecla, atualiza 'dir', avanca seed do RNG
;================================================================
s_read_input:
        PUSH    R0
        PUSH    R1

        LOAD    R0, seed
        INC     R0
        STORE   seed, R0               ; mistura a entropia a cada frame

        INCHAR  R0                     ; R0 = tecla pressionada

        LOADN   R1, #119             ; 'w'
        CMP     R0, R1
        JEQ     ri_up
        LOADN   R1, #97             ; 'a'
        CMP     R0, R1
        JEQ     ri_left
        LOADN   R1, #115             ; 's'
        CMP     R0, R1
        JEQ     ri_down
        LOADN   R1, #100             ; 'd'
        CMP     R0, R1
        JEQ     ri_right
        JMP     ri_done

ri_up:
        LOAD    R0, dir
        LOADN   R1, #40                ; se ja vai pra baixo, ignora (nao reverte)
        CMP     R0, R1
        JEQ     ri_done
        LOADN   R0, #65496             ; -40 (sobe uma linha)
        STORE   dir, R0
        JMP     ri_done

ri_down:
        LOAD    R0, dir
        LOADN   R1, #65496
        CMP     R0, R1
        JEQ     ri_done
        LOADN   R0, #40
        STORE   dir, R0
        JMP     ri_done

ri_left:
        LOAD    R0, dir
        LOADN   R1, #1
        CMP     R0, R1
        JEQ     ri_done
        LOADN   R0, #65535             ; -1
        STORE   dir, R0
        JMP     ri_done

ri_right:
        LOAD    R0, dir
        LOADN   R1, #65535
        CMP     R0, R1
        JEQ     ri_done
        LOADN   R0, #1
        STORE   dir, R0

ri_done:
        POP     R1
        POP     R0
        RTS

;================================================================
; s_advance_snake — move 1 passo. R5 = 1 vivo, 0 colidiu.
;================================================================
s_advance_snake:
        PUSH    R0
        PUSH    R1
        PUSH    R2
        PUSH    R3
        PUSH    R4
        PUSH    R6

        LOADN   R6, #0                 ; flag "comeu fruta nesse passo"

        ; ---- pega cabeca atual ----
        LOAD    R0, head_idx
        LOADN   R1, #snake_buf
        ADD     R1, R1, R0
        LOADI   R2, R1                 ; R2 = pos cabeca antiga
        STORE   old_head_pos, R2       ; salva pra redesenhar depois

        ; ---- calcula nova cabeca ----
        LOAD    R3, dir
        ADD     R2, R2, R3             ; R2 = nova pos cabeca

        ; ---- colisao com parede ----
        LOADN   R0, #40
        CMP     R2, R0
        JLE     as_dead                ; pos < 40 -> topo
        LOADN   R0, #1159
        CMP     R2, R0
        JGR     as_dead                ; pos > 1159 -> base
        LOADN   R0, #40
        MOD     R3, R2, R0             ; R3 = coluna
        LOADN   R0, #0
        CMP     R3, R0
        JEQ     as_dead                ; col 0
        LOADN   R0, #39
        CMP     R3, R0
        JEQ     as_dead                ; col 39

        ; ---- comeu fruta? ----
        LOAD    R3, food_pos
        CMP     R2, R3
        JEQ     as_ate
        JMP     as_not_ate

as_ate:
        LOADN   R6, #1
        CALL    s_place_food
        JMP     as_after_tail

as_not_ate:
        ; apaga cauda (libera espaco antes da checagem de auto-colisao)
        LOAD    R0, tail_idx
        LOADN   R1, #snake_buf
        ADD     R1, R1, R0
        LOADI   R3, R1                 ; R3 = pos cauda
        LOADN   R4, #32                ; ' ' (ASCII 32)
        OUTCHAR R4, R3                 ; pinta espaco
        INC     R0
        LOADN   R1, #256               ; tamanho do buffer circular
        MOD     R0, R0, R1
        STORE   tail_idx, R0

as_after_tail:
        ; ---- auto-colisao ----
        ; varrer "length - 1 + R6" segmentos (R6 ajusta se comeu)
        LOAD    R1, length
        DEC     R1
        ADD     R1, R1, R6
        LOADN   R0, #0
        CMP     R1, R0
        JEQ     as_skip_self           ; defesa: cobra de 1 segmento

        LOAD    R0, tail_idx
as_self_loop:
        LOADN   R4, #snake_buf
        ADD     R4, R4, R0
        LOADI   R4, R4                 ; R4 = snake_buf[R0]
        CMP     R4, R2
        JEQ     as_dead                ; nova cabeca colidiu com corpo
        INC     R0
        LOADN   R4, #256
        MOD     R0, R0, R4
        DEC     R1
        JNZ     as_self_loop

as_skip_self:
        ; ---- redesenha cabeca antiga como corpo ----
        LOAD    R3, old_head_pos
        LOADN   R4, #591             ; 'O' verde
        OUTCHAR R4, R3

        ; ---- avanca head_idx e grava nova pos ----
        LOAD    R0, head_idx
        INC     R0
        LOADN   R1, #256
        MOD     R0, R0, R1
        STORE   head_idx, R0
        LOADN   R1, #snake_buf
        ADD     R1, R1, R0
        STOREI  R1, R2                 ; buffer[head_idx] = nova pos

        ; ---- length += R6 ----
        LOAD    R1, length
        ADD     R1, R1, R6
        STORE   length, R1

        ; ---- desenha nova cabeca ----
        LOADN   R4, #2880             ; '@' amarelo
        OUTCHAR R4, R2

        LOADN   R5, #1                 ; vivo
        JMP     as_done

as_dead:
        LOADN   R5, #0                 ; morto

as_done:
        POP     R6
        POP     R4
        POP     R3
        POP     R2
        POP     R1
        POP     R0
        RTS

;================================================================
; s_place_food — sorteia pos livre e desenha '*' vermelho
;================================================================
s_place_food:
        PUSH    R0
        PUSH    R1
        PUSH    R2
        PUSH    R3
        PUSH    R4

pf_retry:
        ; LCG: seed = seed * 25173 + 13849
        LOAD    R0, seed
        LOADN   R1, #25173
        MUL     R0, R0, R1
        LOADN   R1, #13849
        ADD     R0, R0, R1
        STORE   seed, R0
        LOADN   R1, #1200
        MOD     R0, R0, R1             ; R0 = candidato em 0..1199

        ; rejeita bordas
        LOADN   R1, #40
        MOD     R2, R0, R1             ; R2 = coluna
        LOADN   R3, #0
        CMP     R2, R3
        JEQ     pf_retry
        LOADN   R3, #39
        CMP     R2, R3
        JEQ     pf_retry
        LOADN   R3, #40
        CMP     R0, R3
        JLE     pf_retry
        LOADN   R3, #1159
        CMP     R0, R3
        JGR     pf_retry

        ; rejeita se cair sobre a cobra
        LOAD    R3, tail_idx
        LOAD    R4, length
pf_check:
        LOADN   R2, #snake_buf
        ADD     R2, R2, R3
        LOADI   R2, R2
        CMP     R2, R0
        JEQ     pf_retry
        INC     R3
        LOADN   R2, #256
        MOD     R3, R3, R2
        DEC     R4
        JNZ     pf_check

        ; ok: salva e desenha
        STORE   food_pos, R0
        LOADN   R1, #2346             ; '*' vermelho
        OUTCHAR R1, R0

        POP     R4
        POP     R3
        POP     R2
        POP     R1
        POP     R0
        RTS

;================================================================
; s_delay — gasta ciclos pra regular a velocidade do jogo
;================================================================
; Ajuste o contador conforme o clock selecionado (SeletorClock):
;   1 MHz  -> #50000 (50000) da ~1 passo/200ms
;   12 MHz -> #65535 da ~1 passo/200ms
;================================================================
s_delay:
        PUSH    R0
        LOADN   R0, #50000
delay_loop:
        DEC     R0
        JNZ     delay_loop
        POP     R0
        RTS

;================================================================
; s_show_game_over — escreve "GAME OVER" no centro da tela
;================================================================
; Letras em codigo (ASCII - 32):  G=h27 A=h21 M=h2D E=h25 sp=h00
;                                  O=h2F V=h36 R=h32
;================================================================
s_show_game_over:
        PUSH    R0
        PUSH    R1

        LOADN   R1, #575               ; (linha 14, col 15)
        LOADN   R0, #2375             ; G vermelho
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2369             ; A
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2381             ; M
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2373             ; E
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2336             ; espaco
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2383             ; O
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2390             ; V
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2373             ; E
        OUTCHAR R0, R1
        INC     R1
        LOADN   R0, #2386             ; R
        OUTCHAR R0, R1

        POP     R1
        POP     R0
        RTS


;================================================================
; ============== T E T R I S ==============
;================================================================
; Board 10x20 mostrado em screen cols 14..23, rows 4..23
; Pecas: 7 tipos (I,O,T,S,Z,J,L) x 4 rotacoes encoded em bitmap 4x4
; Controles: A=esq, D=dir, S=desce, W=rotaciona, Q=sai
;================================================================

cmd_tetris:
        call    kclear_screen
        call    t_init_board
        call    t_draw_frame
        loadn   r0, #1
        store   t_seed, r0
        call    t_spawn
        loadn   r0, #0
        cmp     r5, r0
        jeq     tet_over
tet_loop:
        call    t_input
        loadn   r0, #1
        cmp     r5, r0
        jeq     tet_quit
        call    s_delay
        load    r0, t_grav
        inc     r0
        store   t_grav, r0
        loadn   r1, #4
        cmp     r0, r1
        jle     tet_skip
        loadn   r0, #0
        store   t_grav, r0
        call    t_undraw_piece
        call    t_try_down
        loadn   r0, #1
        cmp     r5, r0
        jeq     tet_drew
        call    t_draw_piece
        call    t_lock
        call    t_clear_lines
        call    t_spawn
        loadn   r0, #0
        cmp     r5, r0
        jeq     tet_over
        jmp     tet_skip
tet_drew:
        call    t_draw_piece
tet_skip:
        jmp     tet_loop
tet_quit:
tet_over:
        call    s_wait_any_key
        call    kclear_screen
        call    show_banner
        rts

;----------------------------------------------------------------
; t_init_board — zera t_board[200]
;----------------------------------------------------------------
t_init_board:
        push    r0
        push    r1
        push    r2
        loadn   r0, #t_board
        loadn   r1, #200
        loadn   r2, #0
tib_loop:
        storei  r0, r2
        inc     r0
        dec     r1
        jnz     tib_loop
        loadn   r0, #0
        store   t_grav, r0
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_draw_frame — borda '|' nos lados e '-' embaixo
;----------------------------------------------------------------
t_draw_frame:
        push    r0
        push    r1
        push    r2
        push    r3
        ; lados (esq col 13, dir col 24, rows 4..23)
        loadn   r0, #4
tdf_side:
        loadn   r1, #40
        mul     r2, r0, r1
        loadn   r1, #13
        add     r2, r2, r1                  ; pos esq
        loadn   r3, #547                    ; verde '#'
        outchar r3, r2
        loadn   r1, #11
        add     r2, r2, r1                  ; pos dir = pos esq + 11
        outchar r3, r2
        inc     r0
        loadn   r1, #24
        cmp     r0, r1
        jne     tdf_side
        ; fundo (row 24, cols 13..24)
        loadn   r0, #13
tdf_bot:
        loadn   r1, #960                    ; 24*40
        add     r2, r1, r0
        loadn   r3, #547
        outchar r3, r2
        inc     r0
        loadn   r1, #25
        cmp     r0, r1
        jne     tdf_bot
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_get_cells — decodifica bitmap em t_cells[8] (4 pares x,y)
;   in: r0=piece, r1=rot
;----------------------------------------------------------------
t_get_cells:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        push    r6
        loadn   r2, #4
        mul     r0, r0, r2
        add     r0, r0, r1                  ; index
        loadn   r2, #piece_data
        add     r2, r2, r0
        loadi   r0, r2                      ; r0 = bitmap
        loadn   r1, #0                      ; bit index
        loadn   r2, #t_cells
        loadn   r3, #1                      ; mask
tgc_loop:
        and     r4, r0, r3
        loadn   r5, #0
        cmp     r4, r5
        jeq     tgc_skip
        loadn   r5, #3
        and     r6, r1, r5                  ; x = i & 3
        storei  r2, r6
        inc     r2
        loadn   r5, #4
        div     r6, r1, r5                  ; y = i / 4
        storei  r2, r6
        inc     r2
tgc_skip:
        inc     r1
        add     r3, r3, r3                  ; mask <<= 1
        loadn   r4, #16
        cmp     r1, r4
        jne     tgc_loop
        pop     r6
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_check_collision_at — r0=tx, r1=ty, r2=trot -> r5=1 se colidiu
;----------------------------------------------------------------
t_check_collision_at:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r6
        store   t_test_x, r0
        store   t_test_y, r1
        load    r0, t_piece
        mov     r1, r2
        call    t_get_cells
        loadn   r0, #t_cells
        loadn   r1, #4
tcc_loop:
        loadi   r2, r0
        inc     r0
        loadi   r3, r0
        inc     r0
        load    r4, t_test_x
        add     r2, r2, r4
        load    r4, t_test_y
        add     r3, r3, r4
        loadn   r4, #10
        cmp     r2, r4
        jeg     tcc_hit
        loadn   r4, #20
        cmp     r3, r4
        jeg     tcc_hit
        loadn   r4, #10
        mul     r3, r3, r4
        add     r3, r3, r2
        loadn   r4, #t_board
        add     r4, r4, r3
        loadi   r6, r4
        loadn   r4, #0
        cmp     r6, r4
        jne     tcc_hit
        dec     r1
        jnz     tcc_loop
        loadn   r5, #0
        jmp     tcc_done
tcc_hit:
        loadn   r5, #1
tcc_done:
        pop     r6
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_draw_piece / t_undraw_piece
;----------------------------------------------------------------
t_draw_piece:
        push    r0
        push    r1
        loadn   r0, #3160                   ; azul 'X'
        store   t_drawchar, r0
        call    t_paint_piece
        pop     r1
        pop     r0
        rts

t_undraw_piece:
        push    r0
        push    r1
        loadn   r0, #32                     ; espaco
        store   t_drawchar, r0
        call    t_paint_piece
        pop     r1
        pop     r0
        rts

t_paint_piece:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        push    r6
        load    r0, t_piece
        load    r1, t_rot
        call    t_get_cells
        loadn   r2, #t_cells
        loadn   r3, #4
tpp_loop:
        loadi   r4, r2
        inc     r2
        loadi   r5, r2
        inc     r2
        load    r6, t_x
        add     r4, r4, r6
        loadn   r6, #14
        add     r4, r4, r6                  ; screen_x
        load    r6, t_y
        add     r5, r5, r6
        loadn   r6, #4
        add     r5, r5, r6                  ; screen_y
        loadn   r6, #40
        mul     r5, r5, r6
        add     r5, r5, r4                  ; pos
        load    r6, t_drawchar
        outchar r6, r5
        dec     r3
        jnz     tpp_loop
        pop     r6
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_spawn — sorteia peca e tenta posicionar no topo
;----------------------------------------------------------------
t_spawn:
        push    r0
        push    r1
        push    r2
        load    r0, t_seed
        loadn   r1, #25173
        mul     r0, r0, r1
        loadn   r1, #13849
        add     r0, r0, r1
        store   t_seed, r0
        loadn   r1, #7
        mod     r0, r0, r1
        store   t_piece, r0
        loadn   r0, #0
        store   t_rot, r0
        loadn   r0, #3
        store   t_x, r0
        loadn   r0, #0
        store   t_y, r0
        loadn   r0, #3
        loadn   r1, #0
        loadn   r2, #0
        call    t_check_collision_at
        loadn   r0, #1
        cmp     r5, r0
        jeq     tsp_fail
        call    t_draw_piece
        loadn   r5, #1
        jmp     tsp_done
tsp_fail:
        loadn   r5, #0
tsp_done:
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_try_left / t_try_right / t_try_down / t_try_rotate
;----------------------------------------------------------------
t_try_left:
        push    r0
        push    r1
        push    r2
        load    r0, t_x
        dec     r0
        load    r1, t_y
        load    r2, t_rot
        call    t_check_collision_at
        loadn   r0, #1
        cmp     r5, r0
        jeq     ttl_no
        load    r0, t_x
        dec     r0
        store   t_x, r0
ttl_no:
        pop     r2
        pop     r1
        pop     r0
        rts

t_try_right:
        push    r0
        push    r1
        push    r2
        load    r0, t_x
        inc     r0
        load    r1, t_y
        load    r2, t_rot
        call    t_check_collision_at
        loadn   r0, #1
        cmp     r5, r0
        jeq     ttr_no
        load    r0, t_x
        inc     r0
        store   t_x, r0
ttr_no:
        pop     r2
        pop     r1
        pop     r0
        rts

t_try_down:
        push    r0
        push    r1
        push    r2
        load    r0, t_x
        load    r1, t_y
        inc     r1
        load    r2, t_rot
        call    t_check_collision_at
        loadn   r0, #1
        cmp     r5, r0
        jeq     ttd_no
        load    r0, t_y
        inc     r0
        store   t_y, r0
        loadn   r5, #1
        jmp     ttd_done
ttd_no:
        loadn   r5, #0
ttd_done:
        pop     r2
        pop     r1
        pop     r0
        rts

t_try_rotate:
        push    r0
        push    r1
        push    r2
        push    r3
        load    r0, t_x
        load    r1, t_y
        load    r2, t_rot
        inc     r2
        loadn   r3, #4
        mod     r2, r2, r3
        call    t_check_collision_at
        loadn   r0, #1
        cmp     r5, r0
        jeq     trt_no
        load    r0, t_rot
        inc     r0
        loadn   r3, #4
        mod     r0, r0, r3
        store   t_rot, r0
trt_no:
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_input — le teclado, faz undraw/move/draw imediato
;----------------------------------------------------------------
t_input:
        push    r0
        push    r1
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jeq     tin_done
        loadn   r1, #'q'
        cmp     r0, r1
        jeq     tin_quit
        loadn   r1, #'a'
        cmp     r0, r1
        jeq     tin_l
        loadn   r1, #'d'
        cmp     r0, r1
        jeq     tin_r
        loadn   r1, #'s'
        cmp     r0, r1
        jeq     tin_d
        loadn   r1, #'w'
        cmp     r0, r1
        jeq     tin_w
        jmp     tin_done
tin_l:
        call    t_undraw_piece
        call    t_try_left
        call    t_draw_piece
        jmp     tin_rel
tin_r:
        call    t_undraw_piece
        call    t_try_right
        call    t_draw_piece
        jmp     tin_rel
tin_d:
        call    t_undraw_piece
        call    t_try_down
        call    t_draw_piece
        jmp     tin_rel
tin_w:
        call    t_undraw_piece
        call    t_try_rotate
        call    t_draw_piece
        jmp     tin_rel
tin_quit:
        loadn   r5, #1
        jmp     tin_done_quit
tin_rel:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     tin_rel
tin_done:
        loadn   r5, #0
tin_done_quit:
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_lock — escreve peca atual em t_board
;----------------------------------------------------------------
t_lock:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        push    r6
        load    r0, t_piece
        load    r1, t_rot
        call    t_get_cells
        loadn   r2, #t_cells
        loadn   r3, #4
tlk_loop:
        loadi   r4, r2
        inc     r2
        loadi   r5, r2
        inc     r2
        load    r6, t_x
        add     r4, r4, r6
        load    r6, t_y
        add     r5, r5, r6
        loadn   r6, #10
        mul     r5, r5, r6
        add     r5, r5, r4
        loadn   r4, #t_board
        add     r4, r4, r5
        loadn   r6, #1
        storei  r4, r6
        dec     r3
        jnz     tlk_loop
        pop     r6
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_clear_lines — remove linhas cheias
;----------------------------------------------------------------
t_clear_lines:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        push    r6
        loadn   r0, #19
tcl_row:
        loadn   r1, #10
        loadn   r2, #1
tcl_col:
        loadn   r3, #10
        mul     r4, r0, r3
        loadn   r3, #10
        sub     r3, r3, r1
        add     r4, r4, r3
        loadn   r3, #t_board
        add     r3, r3, r4
        loadi   r4, r3
        loadn   r5, #0
        cmp     r4, r5
        jeq     tcl_not_full
        dec     r1
        jnz     tcl_col
        mov     r6, r0
        call    t_shift_into
        jmp     tcl_again
tcl_not_full:
        loadn   r1, #0
        cmp     r0, r1
        jeq     tcl_done
        dec     r0
        jmp     tcl_row
tcl_again:
        jmp     tcl_row
tcl_done:
        call    t_redraw_board
        pop     r6
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_shift_into (r6 = dest row): rolls everything above dest down
;----------------------------------------------------------------
t_shift_into:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        mov     r1, r6
tsi_row:
        loadn   r2, #0
        cmp     r1, r2
        jeq     tsi_zero
        loadn   r2, #0
tsi_col:
        loadn   r3, #10
        mul     r4, r1, r3
        add     r4, r4, r2                  ; dst idx
        mov     r5, r1
        dec     r5
        loadn   r3, #10
        mul     r3, r5, r3
        add     r3, r3, r2                  ; src idx
        loadn   r5, #t_board
        add     r3, r3, r5
        loadi   r5, r3                      ; src val
        loadn   r3, #t_board
        add     r4, r4, r3
        storei  r4, r5
        inc     r2
        loadn   r3, #10
        cmp     r2, r3
        jne     tsi_col
        dec     r1
        jmp     tsi_row
tsi_zero:
        loadn   r2, #0
tsz_col:
        loadn   r3, #t_board
        add     r3, r3, r2
        loadn   r4, #0
        storei  r3, r4
        inc     r2
        loadn   r3, #10
        cmp     r2, r3
        jne     tsz_col
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; t_redraw_board — redesenha as 200 celulas
;----------------------------------------------------------------
t_redraw_board:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        loadn   r0, #0
trb_row:
        loadn   r1, #0
trb_col:
        loadn   r2, #10
        mul     r2, r0, r2
        add     r2, r2, r1
        loadn   r3, #t_board
        add     r3, r3, r2
        loadi   r4, r3
        loadn   r3, #4
        add     r3, r3, r0
        loadn   r2, #40
        mul     r3, r3, r2
        loadn   r2, #14
        add     r3, r3, r2
        add     r3, r3, r1
        loadn   r2, #0
        cmp     r4, r2
        jne     trb_fill
        loadn   r5, #32
        jmp     trb_draw
trb_fill:
        loadn   r5, #3160
trb_draw:
        outchar r5, r3
        inc     r1
        loadn   r2, #10
        cmp     r1, r2
        jne     trb_col
        inc     r0
        loadn   r2, #20
        cmp     r0, r2
        jne     trb_row
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts


;================================================================
;================================================================
; ============== D O N U T (a1k0n.net algorithm) ==============
;================================================================
; Implementacao real do donut.c do Andy Sloane usando ponto fixo
; escala 64 (4.4 fp signed). Toda multiplicacao seguida de /64 com
; preservacao de sinal via sd64.
;
; Torus: R1=1 (tube), R2=2 (ring), K2=5 (camera). Escala 64:
;   R1_scaled = 64, R2_scaled = 128, K2_scaled = 320
; Projecao: xp = 20 + K1*x/z (K1=25), yp = 15 - K1y*y/z (K1y=12)
; Pressione qualquer tecla para sair.
;----------------------------------------------------------------

cmd_donut:
        push    r0
        push    r1
        loadn   r0, #0
        store   d_A, r0
        store   d_B, r0
do_frame:
        ; --- precompute trig for A and B ---
        load    r0, d_A
        call    d_sin
        store   d_sinA, r5
        load    r0, d_A
        call    d_cos
        store   d_cosA, r5
        load    r0, d_B
        call    d_sin
        store   d_sinB, r5
        load    r0, d_B
        call    d_cos
        store   d_cosB, r5

        call    d_clear_zbuf
        call    kclear_screen

        ; --- theta loop (32 steps) ---
        loadn   r0, #0
        store   d_theta, r0
do_theta:
        load    r0, d_theta
        loadn   r1, #2
        mul     r0, r0, r1                  ; theta_idx = i*2 (32 steps cover 64)
        call    d_sin
        store   d_sinT, r5
        load    r0, d_theta
        loadn   r1, #2
        mul     r0, r0, r1
        call    d_cos
        store   d_cosT, r5

        ; circle_x = R2 + cos_theta  (R2=128 scale, R1=64 cancels with /64)
        load    r0, d_cosT
        loadn   r1, #128
        add     r0, r0, r1
        store   d_circx, r0
        load    r0, d_sinT
        store   d_circy, r0

        ; --- phi loop (64 steps) ---
        loadn   r0, #0
        store   d_phi, r0
do_phi:
        load    r0, d_phi
        call    d_sin
        store   d_sinP, r5
        load    r0, d_phi
        call    d_cos
        store   d_cosP, r5

        call    d_pixel

        load    r0, d_phi
        inc     r0
        store   d_phi, r0
        loadn   r1, #64
        cmp     r0, r1
        jne     do_phi

        load    r0, d_theta
        inc     r0
        store   d_theta, r0
        loadn   r1, #32
        cmp     r0, r1
        jne     do_theta

        ; advance A and B (rotation speeds)
        load    r0, d_A
        loadn   r1, #2
        add     r0, r0, r1
        loadn   r1, #63
        and     r0, r0, r1
        store   d_A, r0
        load    r0, d_B
        inc     r0
        loadn   r1, #63
        and     r0, r0, r1
        store   d_B, r0

        ; check key
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     d_quit
        jmp     do_frame

d_quit:
d_rel2:
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jne     d_rel2
        call    kclear_screen
        call    show_banner
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; d_pixel — processa um (theta, phi). Usa d_sinT/cosT/sinP/cosP/
;   sinA/cosA/sinB/cosB/circx/circy. Escreve em zbuf e tela.
;----------------------------------------------------------------
d_pixel:
        push    r0
        push    r1
        push    r2

        ; ---- z = K2 + cosA*circx*sinP + circy*sinA ----
        load    r0, d_cosA
        load    r1, d_circx
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinP
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0

        load    r0, d_circy
        load    r1, d_sinA
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        add     r0, r0, r1
        loadn   r1, #320
        add     r0, r0, r1
        store   d_z, r0

        ; z must be positive (camera in front)
        loadn   r1, #32768
        cmp     r0, r1
        jeg     dp_skip
        loadn   r1, #1
        cmp     r0, r1
        jle     dp_skip                     ; z < 1, too close / singular

        ; ---- x = circx*(cosB*cosP + sinA*sinB*sinP) - circy*cosA*sinB ----
        load    r0, d_cosB
        load    r1, d_cosP
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0

        load    r0, d_sinA
        load    r1, d_sinB
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinP
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        add     r0, r0, r1                  ; cosB*cosP + sinA*sinB*sinP
        load    r1, d_circx
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0

        load    r0, d_circy
        load    r1, d_cosA
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinB
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        sub     r0, r1, r0
        store   d_x, r0

        ; ---- y = circx*(sinB*cosP - sinA*cosB*sinP) + circy*cosA*cosB ----
        load    r0, d_sinB
        load    r1, d_cosP
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0

        load    r0, d_sinA
        load    r1, d_cosB
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinP
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        sub     r0, r1, r0                  ; sinB*cosP - sinA*cosB*sinP
        load    r1, d_circx
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0

        load    r0, d_circy
        load    r1, d_cosA
        mul     r0, r0, r1
        call    sd64
        load    r1, d_cosB
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        add     r0, r0, r1
        store   d_y, r0

        ; ---- xp = 20 + K1*x/z (K1=25) ----
        load    r0, d_x
        loadn   r1, #25
        mul     r0, r0, r1
        load    r1, d_z
        call    sdiv
        loadn   r1, #20
        add     r0, r0, r1
        ; check 0 <= xp < 40
        loadn   r1, #32768
        cmp     r0, r1
        jeg     dp_skip                     ; xp < 0
        loadn   r1, #40
        cmp     r0, r1
        jeg     dp_skip
        store   d_xp, r0

        ; ---- yp = 15 - K1y*y/z (K1y=12 aspect) ----
        load    r0, d_y
        loadn   r1, #12
        mul     r0, r0, r1
        load    r1, d_z
        call    sdiv
        loadn   r1, #15
        sub     r0, r1, r0
        loadn   r1, #32768
        cmp     r0, r1
        jeg     dp_skip
        loadn   r1, #30
        cmp     r0, r1
        jeg     dp_skip
        store   d_yp, r0

        ; idx = yp*40 + xp
        loadn   r1, #40
        mul     r0, r0, r1
        load    r1, d_xp
        add     r0, r0, r1
        store   d_idx, r0

        ; ---- L = cosP*cosT*sinB - cosA*cosT*sinP - sinA*sinT
        ;        + cosB*(cosA*sinT - cosT*sinA*sinP) ----
        load    r0, d_cosP
        load    r1, d_cosT
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinB
        mul     r0, r0, r1
        call    sd64
        store   d_L, r0

        load    r0, d_cosA
        load    r1, d_cosT
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinP
        mul     r0, r0, r1
        call    sd64
        load    r1, d_L
        sub     r0, r1, r0
        store   d_L, r0

        load    r0, d_sinA
        load    r1, d_sinT
        mul     r0, r0, r1
        call    sd64
        load    r1, d_L
        sub     r0, r1, r0
        store   d_L, r0

        load    r0, d_cosA
        load    r1, d_sinT
        mul     r0, r0, r1
        call    sd64
        store   d_tmp, r0
        load    r0, d_cosT
        load    r1, d_sinA
        mul     r0, r0, r1
        call    sd64
        load    r1, d_sinP
        mul     r0, r0, r1
        call    sd64
        load    r1, d_tmp
        sub     r0, r1, r0
        load    r1, d_cosB
        mul     r0, r0, r1
        call    sd64
        load    r1, d_L
        add     r0, r0, r1
        store   d_L, r0

        ; check L > 0
        loadn   r1, #32768
        cmp     r0, r1
        jeg     dp_skip                     ; L negative
        loadn   r1, #0
        cmp     r0, r1
        jeq     dp_skip                     ; L = 0

        ; ---- z-buffer (lower z = closer wins) ----
        load    r0, d_idx
        loadn   r1, #d_zbuf
        add     r1, r1, r0
        loadi   r2, r1                      ; r2 = zbuf[idx]
        load    r0, d_z
        cmp     r2, r0
        jle     dp_skip                     ; existing closer
        jeq     dp_skip
        storei  r1, r0                      ; zbuf[idx] = z

        ; ---- pick char: idx = L/8 clamped to 0..11 ----
        load    r0, d_L
        loadn   r1, #8
        div     r0, r0, r1
        loadn   r1, #11
        cmp     r0, r1
        jle     dp_lum_ok
        loadn   r0, #11
dp_lum_ok:
        loadn   r1, #d_lum_chars
        add     r1, r1, r0
        loadi   r0, r1
        loadn   r1, #2816                   ; cor 11 (amarelo) << 8
        add     r0, r0, r1
        load    r1, d_idx
        outchar r0, r1

dp_skip:
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; d_sin / d_cos — input r0 = angle 0..63; output r5 = sin/cos scale 64
;----------------------------------------------------------------
d_sin:
        push    r0
        push    r1
        loadn   r1, #63
        and     r0, r0, r1
        loadn   r1, #d_sin_table
        add     r1, r1, r0
        loadi   r5, r1
        pop     r1
        pop     r0
        rts

d_cos:
        push    r0
        push    r1
        loadn   r1, #16
        add     r0, r0, r1
        loadn   r1, #63
        and     r0, r0, r1
        loadn   r1, #d_sin_table
        add     r1, r1, r0
        loadi   r5, r1
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; sd64 — r0 = signed(r0) / 64
;----------------------------------------------------------------
sd64:
        push    r1
        loadn   r1, #32768
        cmp     r0, r1
        jeg     sd64_neg
        loadn   r1, #64
        div     r0, r0, r1
        jmp     sd64_done
sd64_neg:
        not     r0, r0
        inc     r0
        loadn   r1, #64
        div     r0, r0, r1
        not     r0, r0
        inc     r0
sd64_done:
        pop     r1
        rts

;----------------------------------------------------------------
; sdiv — r0 = signed(r0) / signed(r1)
;----------------------------------------------------------------
sdiv:
        push    r2
        push    r3
        push    r4
        loadn   r4, #0
        loadn   r3, #32768
        cmp     r0, r3
        jle     sdiv_r0p
        not     r0, r0
        inc     r0
        loadn   r2, #1
        xor     r4, r4, r2
sdiv_r0p:
        cmp     r1, r3
        jle     sdiv_r1p
        not     r1, r1
        inc     r1
        loadn   r2, #1
        xor     r4, r4, r2
sdiv_r1p:
        div     r0, r0, r1
        loadn   r2, #0
        cmp     r4, r2
        jeq     sdiv_done
        not     r0, r0
        inc     r0
sdiv_done:
        pop     r4
        pop     r3
        pop     r2
        rts

;----------------------------------------------------------------
; d_clear_zbuf — preenche zbuf com 32000 (far)
;----------------------------------------------------------------
d_clear_zbuf:
        push    r0
        push    r1
        push    r2
        loadn   r0, #d_zbuf
        loadn   r1, #1200
        loadn   r2, #32000
d_cz_loop:
        storei  r0, r2
        inc     r0
        dec     r1
        jnz     d_cz_loop
        pop     r2
        pop     r1
        pop     r0
        rts

;================================================================
; ============== S P A C E   I N V A D E R S ==============
;================================================================
; Grade de 4x8 invasores que descem em ziguezague. O jogador (nave
; 'A' ciano na base) anda com A/D e atira com ESPACO (1 tiro por
; vez). Os invasores soltam bombas '!' a partir do mais baixo de
; uma coluna sorteada. Vitoria: destruir todos. Derrota: ser
; atingido por uma bomba ou deixar os invasores chegarem a base.
; Q sai de volta ao shell.
;
; Mapeamento: invasor (c,r) -> coluna = ax + c*3 , linha = ay + r*2
;   ax in [1..17], ay sobe 1 a cada reversao de borda.
; Cores (cor*256 + ascii): invasor 'W' verde, nave 'A' ciano,
;   tiro '|' amarelo, bomba '!' vermelho.
;----------------------------------------------------------------

cmd_invaders:
        call    kclear_screen
        call    i_draw_hud
        call    i_init
iv_loop:
        call    i_input
        loadn   r0, #1
        cmp     r5, r0
        jeq     iv_quit
        call    i_bullet_step
        call    i_bomb_step
        loadn   r0, #2
        cmp     r5, r0
        jeq     iv_dead
        load    r0, iv_step
        inc     r0
        store   iv_step, r0
        loadn   r1, #6
        cmp     r0, r1
        jle     iv_skipmove            ; move o bloco a cada 6 ticks
        loadn   r0, #0
        store   iv_step, r0
        call    i_alien_step
        load    r0, iv_ay
        loadn   r1, #21
        cmp     r0, r1
        jeg     iv_dead                ; invasores alcancaram a base
iv_skipmove:
        load    r0, iv_count
        loadn   r1, #0
        cmp     r0, r1
        jeq     iv_win                 ; todos destruidos
        call    i_delay
        jmp     iv_loop
iv_win:
        call    i_show_win
        jmp     iv_end
iv_dead:
        call    i_show_lose
iv_end:
        call    s_wait_any_key
        call    kclear_screen
        call    show_banner
        rts
iv_quit:
        call    kclear_screen
        call    show_banner
        rts

;----------------------------------------------------------------
; i_init — todos invasores vivos, posicoes iniciais, desenha tudo
;----------------------------------------------------------------
i_init:
        push    r0
        push    r1
        push    r2
        loadn   r0, #iv_alive
        loadn   r1, #32
        loadn   r2, #1
ii_loop:
        storei  r0, r2
        inc     r0
        dec     r1
        jnz     ii_loop
        loadn   r0, #32
        store   iv_count, r0
        loadn   r0, #9
        store   iv_ax, r0
        loadn   r0, #2
        store   iv_ay, r0
        loadn   r0, #1
        store   iv_adir, r0
        loadn   r0, #19
        store   iv_px, r0
        loadn   r0, #0
        store   iv_bact, r0
        store   iv_dact, r0
        store   iv_step, r0
        store   iv_bombcd, r0
        loadn   r0, #12345
        store   iv_seed, r0
        loadn   r0, #599               ; 'W' verde
        store   iv_apaint, r0
        call    i_paint_aliens
        call    i_draw_player
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_paint_aliens — pinta iv_apaint em cada invasor vivo
;----------------------------------------------------------------
i_paint_aliens:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r5
        push    r6
        loadn   r1, #0                  ; r = linha (0..3)
ipa_row:
        loadn   r2, #0                  ; c = coluna (0..7)
ipa_col:
        loadn   r3, #8
        mul     r3, r1, r3
        add     r3, r3, r2             ; idx = r*8 + c
        loadn   r4, #iv_alive
        add     r4, r4, r3
        loadi   r4, r4
        loadn   r0, #0
        cmp     r4, r0
        jeq     ipa_next               ; morto -> pula
        load    r0, iv_ax
        loadn   r5, #3
        mul     r5, r2, r5
        add     r5, r0, r5            ; coluna_tela = ax + c*3
        load    r0, iv_ay
        loadn   r6, #2
        mul     r6, r1, r6
        add     r6, r0, r6            ; linha_tela = ay + r*2
        loadn   r0, #40
        mul     r6, r6, r0
        add     r6, r6, r5            ; pos = linha*40 + coluna
        load    r0, iv_apaint
        outchar r0, r6
ipa_next:
        inc     r2
        loadn   r0, #8
        cmp     r2, r0
        jne     ipa_col
        inc     r1
        loadn   r0, #4
        cmp     r1, r0
        jne     ipa_row
        pop     r6
        pop     r5
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_alien_step — move o bloco; reverte e desce nas bordas
;----------------------------------------------------------------
i_alien_step:
        push    r0
        push    r1
        push    r2
        push    r3
        loadn   r0, #32                ; apaga bloco na posicao antiga
        store   iv_apaint, r0
        call    i_paint_aliens
        load    r0, iv_ax
        load    r1, iv_adir
        add     r2, r0, r1            ; nax = ax + adir
        loadn   r3, #1
        cmp     r1, r3
        jeq     ias_pos
        loadn   r3, #1                 ; direcao negativa
        cmp     r2, r3
        jle     ias_edge               ; nax < 1
        jmp     ias_move
ias_pos:
        loadn   r3, #17
        cmp     r2, r3
        jgr     ias_edge               ; nax > 17
        jmp     ias_move
ias_edge:
        load    r1, iv_adir
        loadn   r3, #0
        sub     r1, r3, r1            ; adir = -adir
        store   iv_adir, r1
        load    r0, iv_ay
        inc     r0
        store   iv_ay, r0
        jmp     ias_draw
ias_move:
        store   iv_ax, r2
ias_draw:
        loadn   r0, #599               ; redesenha bloco verde
        store   iv_apaint, r0
        call    i_paint_aliens
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_input — A/D move, ESPACO atira, Q sai (r5=1 se Q)
;----------------------------------------------------------------
i_input:
        push    r0
        push    r1
        inchar  r0
        loadn   r1, #255
        cmp     r0, r1
        jeq     iin_done
        loadn   r1, #'q'
        cmp     r0, r1
        jeq     iin_quit
        loadn   r1, #'a'
        cmp     r0, r1
        jeq     iin_left
        loadn   r1, #'d'
        cmp     r0, r1
        jeq     iin_right
        loadn   r1, #32                ; ESPACO = atira
        cmp     r0, r1
        jeq     iin_fire
        jmp     iin_done
iin_left:
        load    r0, iv_px
        loadn   r1, #2
        cmp     r0, r1
        jle     iin_done               ; px < 2 -> nao move
        call    i_erase_player
        load    r0, iv_px
        dec     r0
        store   iv_px, r0
        call    i_draw_player
        jmp     iin_done
iin_right:
        load    r0, iv_px
        loadn   r1, #38
        cmp     r0, r1
        jeg     iin_done               ; px >= 38 -> nao move
        call    i_erase_player
        load    r0, iv_px
        inc     r0
        store   iv_px, r0
        call    i_draw_player
        jmp     iin_done
iin_fire:
        load    r0, iv_bact
        loadn   r1, #0
        cmp     r0, r1
        jne     iin_done               ; ja existe tiro na tela
        loadn   r0, #1
        store   iv_bact, r0
        load    r0, iv_px
        store   iv_bx, r0
        loadn   r0, #27
        store   iv_by, r0
        call    i_draw_bullet
        jmp     iin_done
iin_quit:
        loadn   r5, #1
        pop     r1
        pop     r0
        rts
iin_done:
        loadn   r5, #0
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_draw_player / i_erase_player — nave 'A' (ciano) na linha 28
;----------------------------------------------------------------
i_draw_player:
        push    r0
        push    r1
        load    r0, iv_px
        loadn   r1, #1120              ; 28 * 40
        add     r1, r1, r0
        loadn   r0, #3649              ; 'A' ciano (14*256 + 65)
        outchar r0, r1
        pop     r1
        pop     r0
        rts
i_erase_player:
        push    r0
        push    r1
        load    r0, iv_px
        loadn   r1, #1120
        add     r1, r1, r0
        loadn   r0, #32
        outchar r0, r1
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_draw_bullet / i_erase_bullet — tiro '|' (amarelo)
;----------------------------------------------------------------
i_draw_bullet:
        push    r0
        push    r1
        load    r0, iv_by
        loadn   r1, #40
        mul     r1, r0, r1
        load    r0, iv_bx
        add     r1, r1, r0
        loadn   r0, #2940              ; '|' amarelo (11*256 + 124)
        outchar r0, r1
        pop     r1
        pop     r0
        rts
i_erase_bullet:
        push    r0
        push    r1
        load    r0, iv_by
        loadn   r1, #40
        mul     r1, r0, r1
        load    r0, iv_bx
        add     r1, r1, r0
        loadn   r0, #32
        outchar r0, r1
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_bullet_step — sobe o tiro 1 linha e testa colisao
;----------------------------------------------------------------
i_bullet_step:
        push    r0
        push    r1
        load    r0, iv_bact
        loadn   r1, #0
        cmp     r0, r1
        jeq     ibs_done               ; sem tiro ativo
        call    i_erase_bullet
        load    r0, iv_by
        loadn   r1, #2
        cmp     r0, r1
        jle     ibs_off                ; chegou ao topo
        dec     r0
        store   iv_by, r0
        call    i_check_hit
        loadn   r1, #1
        cmp     r5, r1
        jeq     ibs_hit
        call    i_draw_bullet
        jmp     ibs_done
ibs_hit:
        loadn   r0, #0
        store   iv_bact, r0
        jmp     ibs_done
ibs_off:
        loadn   r0, #0
        store   iv_bact, r0
ibs_done:
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_check_hit — se o tiro (bx,by) bate num invasor vivo, mata-o.
;   r5 = 1 se acertou, 0 senao
;----------------------------------------------------------------
i_check_hit:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        push    r6
        load    r0, iv_bx
        load    r1, iv_ax
        cmp     r0, r1
        jle     ich_no                 ; bx < ax
        sub     r0, r0, r1            ; rel_col = bx - ax
        loadn   r1, #3
        mod     r2, r0, r1
        loadn   r3, #0
        cmp     r2, r3
        jne     ich_no                 ; nao alinhado a coluna
        loadn   r1, #3
        div     r0, r0, r1            ; c = rel_col / 3
        loadn   r1, #8
        cmp     r0, r1
        jeg     ich_no                 ; c >= 8
        load    r2, iv_by
        load    r3, iv_ay
        cmp     r2, r3
        jle     ich_no                 ; by < ay
        sub     r2, r2, r3           ; rel_row = by - ay
        loadn   r3, #2
        mod     r4, r2, r3
        loadn   r1, #0
        cmp     r4, r1
        jne     ich_no                 ; nao alinhado a linha
        loadn   r3, #2
        div     r2, r2, r3           ; r = rel_row / 2
        loadn   r1, #4
        cmp     r2, r1
        jeg     ich_no                 ; r >= 4
        loadn   r1, #8
        mul     r1, r2, r1
        add     r1, r1, r0           ; idx = r*8 + c
        loadn   r3, #iv_alive
        add     r3, r3, r1
        loadi   r4, r3
        loadn   r6, #0
        cmp     r4, r6
        jeq     ich_no                 ; ja morto
        storei  r3, r6                 ; alive[idx] = 0
        load    r6, iv_by              ; apaga invasor (= pos do tiro)
        loadn   r1, #40
        mul     r6, r6, r1
        load    r1, iv_bx
        add     r6, r6, r1
        loadn   r1, #32
        outchar r1, r6
        load    r6, iv_count
        dec     r6
        store   iv_count, r6
        loadn   r5, #1
        jmp     ich_done
ich_no:
        loadn   r5, #0
ich_done:
        pop     r6
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_draw_bomb / i_erase_bomb — bomba '!' (vermelho)
;----------------------------------------------------------------
i_draw_bomb:
        push    r0
        push    r1
        load    r0, iv_dy
        loadn   r1, #40
        mul     r1, r0, r1
        load    r0, iv_dx
        add     r1, r1, r0
        loadn   r0, #2337              ; '!' vermelho (9*256 + 33)
        outchar r0, r1
        pop     r1
        pop     r0
        rts
i_erase_bomb:
        push    r0
        push    r1
        load    r0, iv_dy
        loadn   r1, #40
        mul     r1, r0, r1
        load    r0, iv_dx
        add     r1, r1, r0
        loadn   r0, #32
        outchar r0, r1
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_bomb_step — gera e desce a bomba. r5 = 2 se atingir a nave
;----------------------------------------------------------------
i_bomb_step:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
        load    r0, iv_dact
        loadn   r1, #0
        cmp     r0, r1
        jne     ibo_move               ; bomba ativa -> desce
        load    r0, iv_bombcd
        inc     r0
        store   iv_bombcd, r0
        loadn   r1, #25
        cmp     r0, r1
        jle     ibo_safe               ; ainda em cooldown
        loadn   r1, #0
        store   iv_bombcd, r1
        load    r0, iv_seed            ; LCG
        loadn   r1, #25173
        mul     r0, r0, r1
        loadn   r1, #13849
        add     r0, r0, r1
        store   iv_seed, r0
        loadn   r1, #8
        mod     r2, r0, r1            ; c = coluna sorteada (0..7)
        loadn   r3, #3                 ; varre de baixo p/ cima
ibo_findrow:
        loadn   r0, #8
        mul     r0, r3, r0
        add     r0, r0, r2           ; idx = r*8 + c
        loadn   r1, #iv_alive
        add     r1, r1, r0
        loadi   r1, r1
        loadn   r0, #0
        cmp     r1, r0
        jne     ibo_found              ; invasor vivo mais baixo
        loadn   r0, #0
        cmp     r3, r0
        jeq     ibo_safe               ; coluna sem invasores
        dec     r3
        jmp     ibo_findrow
ibo_found:
        load    r4, iv_ax
        loadn   r0, #3
        mul     r0, r2, r0
        add     r4, r4, r0           ; coluna = ax + c*3
        store   iv_dx, r4
        load    r0, iv_ay
        loadn   r1, #2
        mul     r1, r3, r1
        add     r0, r0, r1
        inc     r0                    ; linha = ay + r*2 + 1
        store   iv_dy, r0
        loadn   r0, #1
        store   iv_dact, r0
        call    i_draw_bomb
        jmp     ibo_safe
ibo_move:
        call    i_erase_bomb
        load    r0, iv_dy
        inc     r0
        store   iv_dy, r0
        loadn   r1, #28
        cmp     r0, r1
        jeq     ibo_reach              ; chegou a linha da nave
        loadn   r1, #29
        cmp     r0, r1
        jgr     ibo_deact              ; saiu da tela
        call    i_draw_bomb
        jmp     ibo_safe
ibo_reach:
        load    r0, iv_dx
        load    r1, iv_px
        cmp     r0, r1
        jeq     ibo_hit
        loadn   r0, #0                 ; errou
        store   iv_dact, r0
        jmp     ibo_safe
ibo_deact:
        loadn   r0, #0
        store   iv_dact, r0
        jmp     ibo_safe
ibo_hit:
        loadn   r0, #0
        store   iv_dact, r0
        loadn   r5, #2
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts
ibo_safe:
        loadn   r5, #0
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_draw_hud — titulo e controles na linha 0
;----------------------------------------------------------------
i_draw_hud:
        push    r0
        push    r1
        push    r2
        push    r3
        loadn   r0, #str_iv_hud
        loadn   r1, #0
ihd_loop:
        loadi   r2, r0
        loadn   r3, #0
        cmp     r2, r3
        jeq     ihd_done
        outchar r2, r1
        inc     r0
        inc     r1
        jmp     ihd_loop
ihd_done:
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_draw_str_at — r0=ptr, r1=pos, r2=cor(*256). Imprime ate null
;----------------------------------------------------------------
i_draw_str_at:
        push    r0
        push    r1
        push    r2
        push    r3
        push    r4
ids_loop:
        loadi   r3, r0
        loadn   r4, #0
        cmp     r3, r4
        jeq     ids_done
        add     r3, r3, r2
        outchar r3, r1
        inc     r0
        inc     r1
        jmp     ids_loop
ids_done:
        pop     r4
        pop     r3
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_show_win / i_show_lose — mensagem no centro
;----------------------------------------------------------------
i_show_win:
        push    r0
        push    r1
        push    r2
        loadn   r0, #str_iv_win
        loadn   r1, #576               ; linha 14, col 16
        loadn   r2, #512               ; verde
        call    i_draw_str_at
        pop     r2
        pop     r1
        pop     r0
        rts
i_show_lose:
        push    r0
        push    r1
        push    r2
        loadn   r0, #str_iv_lose
        loadn   r1, #575               ; linha 14, col 15
        loadn   r2, #2304              ; vermelho
        call    i_draw_str_at
        pop     r2
        pop     r1
        pop     r0
        rts

;----------------------------------------------------------------
; i_delay — regula a velocidade (ajuste conforme o clock)
;----------------------------------------------------------------
i_delay:
        push    r0
        loadn   r0, #20000
idl_loop:
        dec     r0
        jnz     idl_loop
        pop     r0
        rts

; STRINGS
;================================================================
str_prompt: var #3
        static str_prompt + #0, #'>'
        static str_prompt + #1, #32
        static str_prompt + #2, #0

str_unknown: var #3
        static str_unknown + #0, #'?'
        static str_unknown + #1, #10
        static str_unknown + #2, #0

str_help_cmd: var #5
        static str_help_cmd + #0, #'h'
        static str_help_cmd + #1, #'e'
        static str_help_cmd + #2, #'l'
        static str_help_cmd + #3, #'p'
        static str_help_cmd + #4, #0

str_clear_cmd: var #6
        static str_clear_cmd + #0, #'c'
        static str_clear_cmd + #1, #'l'
        static str_clear_cmd + #2, #'e'
        static str_clear_cmd + #3, #'a'
        static str_clear_cmd + #4, #'r'
        static str_clear_cmd + #5, #0

str_snake_cmd: var #6
        static str_snake_cmd + #0, #'s'
        static str_snake_cmd + #1, #'n'
        static str_snake_cmd + #2, #'a'
        static str_snake_cmd + #3, #'k'
        static str_snake_cmd + #4, #'e'
        static str_snake_cmd + #5, #0

str_about_cmd: var #6
        static str_about_cmd + #0, #'a'
        static str_about_cmd + #1, #'b'
        static str_about_cmd + #2, #'o'
        static str_about_cmd + #3, #'u'
        static str_about_cmd + #4, #'t'
        static str_about_cmd + #5, #0

str_colors_cmd: var #7
        static str_colors_cmd + #0, #'c'
        static str_colors_cmd + #1, #'o'
        static str_colors_cmd + #2, #'l'
        static str_colors_cmd + #3, #'o'
        static str_colors_cmd + #4, #'r'
        static str_colors_cmd + #5, #'s'
        static str_colors_cmd + #6, #0

str_banner: var #64
        static str_banner + #0, #'S'
        static str_banner + #1, #'i'
        static str_banner + #2, #'m'
        static str_banner + #3, #'O'
        static str_banner + #4, #'S'
        static str_banner + #5, #32
        static str_banner + #6, #'v'
        static str_banner + #7, #'1'
        static str_banner + #8, #32
        static str_banner + #9, #'-'
        static str_banner + #10, #32
        static str_banner + #11, #'s'
        static str_banner + #12, #'i'
        static str_banner + #13, #'s'
        static str_banner + #14, #'t'
        static str_banner + #15, #'e'
        static str_banner + #16, #'m'
        static str_banner + #17, #'a'
        static str_banner + #18, #32
        static str_banner + #19, #'I'
        static str_banner + #20, #'C'
        static str_banner + #21, #'M'
        static str_banner + #22, #'C'
        static str_banner + #23, #32
        static str_banner + #24, #'3'
        static str_banner + #25, #'2'
        static str_banner + #26, #'K'
        static str_banner + #27, #'B'
        static str_banner + #28, #10
        static str_banner + #29, #'='
        static str_banner + #30, #'='
        static str_banner + #31, #'='
        static str_banner + #32, #'='
        static str_banner + #33, #'='
        static str_banner + #34, #'='
        static str_banner + #35, #'='
        static str_banner + #36, #'='
        static str_banner + #37, #'='
        static str_banner + #38, #'='
        static str_banner + #39, #'='
        static str_banner + #40, #'='
        static str_banner + #41, #'='
        static str_banner + #42, #'='
        static str_banner + #43, #'='
        static str_banner + #44, #'='
        static str_banner + #45, #'='
        static str_banner + #46, #'='
        static str_banner + #47, #'='
        static str_banner + #48, #'='
        static str_banner + #49, #'='
        static str_banner + #50, #'='
        static str_banner + #51, #'='
        static str_banner + #52, #'='
        static str_banner + #53, #'='
        static str_banner + #54, #'='
        static str_banner + #55, #'='
        static str_banner + #56, #'='
        static str_banner + #57, #'='
        static str_banner + #58, #'='
        static str_banner + #59, #'='
        static str_banner + #60, #'='
        static str_banner + #61, #10
        static str_banner + #62, #10
        static str_banner + #63, #0

str_help_text: var #90
        static str_help_text + #0, #'c'
        static str_help_text + #1, #'o'
        static str_help_text + #2, #'m'
        static str_help_text + #3, #'a'
        static str_help_text + #4, #'n'
        static str_help_text + #5, #'d'
        static str_help_text + #6, #'o'
        static str_help_text + #7, #'s'
        static str_help_text + #8, #32
        static str_help_text + #9, #'d'
        static str_help_text + #10, #'i'
        static str_help_text + #11, #'s'
        static str_help_text + #12, #'p'
        static str_help_text + #13, #'o'
        static str_help_text + #14, #'n'
        static str_help_text + #15, #'i'
        static str_help_text + #16, #'v'
        static str_help_text + #17, #'e'
        static str_help_text + #18, #'i'
        static str_help_text + #19, #'s'
        static str_help_text + #20, #':'
        static str_help_text + #21, #10
        static str_help_text + #22, #32
        static str_help_text + #23, #32
        static str_help_text + #24, #'h'
        static str_help_text + #25, #'e'
        static str_help_text + #26, #'l'
        static str_help_text + #27, #'p'
        static str_help_text + #28, #32
        static str_help_text + #29, #32
        static str_help_text + #30, #32
        static str_help_text + #31, #32
        static str_help_text + #32, #'c'
        static str_help_text + #33, #'l'
        static str_help_text + #34, #'e'
        static str_help_text + #35, #'a'
        static str_help_text + #36, #'r'
        static str_help_text + #37, #32
        static str_help_text + #38, #32
        static str_help_text + #39, #32
        static str_help_text + #40, #'a'
        static str_help_text + #41, #'b'
        static str_help_text + #42, #'o'
        static str_help_text + #43, #'u'
        static str_help_text + #44, #'t'
        static str_help_text + #45, #10
        static str_help_text + #46, #32
        static str_help_text + #47, #32
        static str_help_text + #48, #'c'
        static str_help_text + #49, #'o'
        static str_help_text + #50, #'l'
        static str_help_text + #51, #'o'
        static str_help_text + #52, #'r'
        static str_help_text + #53, #'s'
        static str_help_text + #54, #32
        static str_help_text + #55, #32
        static str_help_text + #56, #'s'
        static str_help_text + #57, #'n'
        static str_help_text + #58, #'a'
        static str_help_text + #59, #'k'
        static str_help_text + #60, #'e'
        static str_help_text + #61, #32
        static str_help_text + #62, #32
        static str_help_text + #63, #32
        static str_help_text + #64, #'t'
        static str_help_text + #65, #'e'
        static str_help_text + #66, #'t'
        static str_help_text + #67, #'r'
        static str_help_text + #68, #'i'
        static str_help_text + #69, #'s'
        static str_help_text + #70, #10
        static str_help_text + #71, #32
        static str_help_text + #72, #32
        static str_help_text + #73, #'d'
        static str_help_text + #74, #'o'
        static str_help_text + #75, #'n'
        static str_help_text + #76, #'u'
        static str_help_text + #77, #'t'
        static str_help_text + #78, #10
        static str_help_text + #79, #32
        static str_help_text + #80, #32
        static str_help_text + #81, #'i'
        static str_help_text + #82, #'n'
        static str_help_text + #83, #'v'
        static str_help_text + #84, #'a'
        static str_help_text + #85, #'d'
        static str_help_text + #86, #'e'
        static str_help_text + #87, #'r'
        static str_help_text + #88, #'s'
        static str_help_text + #89, #0

str_about_text: var #126
        static str_about_text + #0, #'S'
        static str_about_text + #1, #'i'
        static str_about_text + #2, #'m'
        static str_about_text + #3, #'O'
        static str_about_text + #4, #'S'
        static str_about_text + #5, #32
        static str_about_text + #6, #'v'
        static str_about_text + #7, #'1'
        static str_about_text + #8, #32
        static str_about_text + #9, #'-'
        static str_about_text + #10, #32
        static str_about_text + #11, #'s'
        static str_about_text + #12, #'i'
        static str_about_text + #13, #'s'
        static str_about_text + #14, #'t'
        static str_about_text + #15, #'e'
        static str_about_text + #16, #'m'
        static str_about_text + #17, #'a'
        static str_about_text + #18, #32
        static str_about_text + #19, #'d'
        static str_about_text + #20, #'i'
        static str_about_text + #21, #'d'
        static str_about_text + #22, #'a'
        static str_about_text + #23, #'t'
        static str_about_text + #24, #'i'
        static str_about_text + #25, #'c'
        static str_about_text + #26, #'o'
        static str_about_text + #27, #10
        static str_about_text + #28, #'P'
        static str_about_text + #29, #'r'
        static str_about_text + #30, #'o'
        static str_about_text + #31, #'c'
        static str_about_text + #32, #'e'
        static str_about_text + #33, #'s'
        static str_about_text + #34, #'s'
        static str_about_text + #35, #'a'
        static str_about_text + #36, #'d'
        static str_about_text + #37, #'o'
        static str_about_text + #38, #'r'
        static str_about_text + #39, #32
        static str_about_text + #40, #'I'
        static str_about_text + #41, #'C'
        static str_about_text + #42, #'M'
        static str_about_text + #43, #'C'
        static str_about_text + #44, #32
        static str_about_text + #45, #'1'
        static str_about_text + #46, #'6'
        static str_about_text + #47, #'-'
        static str_about_text + #48, #'b'
        static str_about_text + #49, #'i'
        static str_about_text + #50, #'t'
        static str_about_text + #51, #','
        static str_about_text + #52, #32
        static str_about_text + #53, #'3'
        static str_about_text + #54, #'2'
        static str_about_text + #55, #'K'
        static str_about_text + #56, #'B'
        static str_about_text + #57, #32
        static str_about_text + #58, #'R'
        static str_about_text + #59, #'A'
        static str_about_text + #60, #'M'
        static str_about_text + #61, #10
        static str_about_text + #62, #'S'
        static str_about_text + #63, #'e'
        static str_about_text + #64, #'m'
        static str_about_text + #65, #32
        static str_about_text + #66, #'M'
        static str_about_text + #67, #'M'
        static str_about_text + #68, #'U'
        static str_about_text + #69, #'.'
        static str_about_text + #70, #32
        static str_about_text + #71, #'S'
        static str_about_text + #72, #'e'
        static str_about_text + #73, #'m'
        static str_about_text + #74, #32
        static str_about_text + #75, #'t'
        static str_about_text + #76, #'i'
        static str_about_text + #77, #'m'
        static str_about_text + #78, #'e'
        static str_about_text + #79, #'r'
        static str_about_text + #80, #'.'
        static str_about_text + #81, #32
        static str_about_text + #82, #'S'
        static str_about_text + #83, #'e'
        static str_about_text + #84, #'m'
        static str_about_text + #85, #32
        static str_about_text + #86, #'d'
        static str_about_text + #87, #'i'
        static str_about_text + #88, #'s'
        static str_about_text + #89, #'c'
        static str_about_text + #90, #'o'
        static str_about_text + #91, #'.'
        static str_about_text + #92, #10
        static str_about_text + #93, #'A'
        static str_about_text + #94, #'p'
        static str_about_text + #95, #'p'
        static str_about_text + #96, #'s'
        static str_about_text + #97, #32
        static str_about_text + #98, #'c'
        static str_about_text + #99, #'o'
        static str_about_text + #100, #'o'
        static str_about_text + #101, #'p'
        static str_about_text + #102, #'e'
        static str_about_text + #103, #'r'
        static str_about_text + #104, #'a'
        static str_about_text + #105, #'t'
        static str_about_text + #106, #'i'
        static str_about_text + #107, #'v'
        static str_about_text + #108, #'o'
        static str_about_text + #109, #'s'
        static str_about_text + #110, #32
        static str_about_text + #111, #'v'
        static str_about_text + #112, #'i'
        static str_about_text + #113, #'a'
        static str_about_text + #114, #32
        static str_about_text + #115, #'C'
        static str_about_text + #116, #'A'
        static str_about_text + #117, #'L'
        static str_about_text + #118, #'L'
        static str_about_text + #119, #'/'
        static str_about_text + #120, #'R'
        static str_about_text + #121, #'T'
        static str_about_text + #122, #'S'
        static str_about_text + #123, #'.'
        static str_about_text + #124, #10
        static str_about_text + #125, #0


;================================================================

;================================================================
; Bitmaps de pecas: 7 pecas x 4 rotacoes = 28 words
; Cada bit i representa celula (i%4, i/4) num grid 4x4
;================================================================
piece_data: var #28
        static piece_data + #0, #240
        static piece_data + #1, #17476
        static piece_data + #2, #240
        static piece_data + #3, #17476
        static piece_data + #4, #51
        static piece_data + #5, #51
        static piece_data + #6, #51
        static piece_data + #7, #51
        static piece_data + #8, #114
        static piece_data + #9, #610
        static piece_data + #10, #624
        static piece_data + #11, #562
        static piece_data + #12, #54
        static piece_data + #13, #561
        static piece_data + #14, #864
        static piece_data + #15, #1122
        static piece_data + #16, #99
        static piece_data + #17, #306
        static piece_data + #18, #1584
        static piece_data + #19, #612
        static piece_data + #20, #113
        static piece_data + #21, #550
        static piece_data + #22, #1136
        static piece_data + #23, #802
        static piece_data + #24, #116
        static piece_data + #25, #1570
        static piece_data + #26, #368
        static piece_data + #27, #547

ring_coords: var #32
        static ring_coords + #0, #632
        static ring_coords + #1, #672
        static ring_coords + #2, #711
        static ring_coords + #3, #750
        static ring_coords + #4, #788
        static ring_coords + #5, #827
        static ring_coords + #6, #865
        static ring_coords + #7, #862
        static ring_coords + #8, #860
        static ring_coords + #9, #858
        static ring_coords + #10, #855
        static ring_coords + #11, #813
        static ring_coords + #12, #772
        static ring_coords + #13, #730
        static ring_coords + #14, #689
        static ring_coords + #15, #648
        static ring_coords + #16, #608
        static ring_coords + #17, #568
        static ring_coords + #18, #529
        static ring_coords + #19, #490
        static ring_coords + #20, #452
        static ring_coords + #21, #413
        static ring_coords + #22, #375
        static ring_coords + #23, #378
        static ring_coords + #24, #380
        static ring_coords + #25, #382
        static ring_coords + #26, #385
        static ring_coords + #27, #427
        static ring_coords + #28, #468
        static ring_coords + #29, #510
        static ring_coords + #30, #551
        static ring_coords + #31, #592

; Pattern: arco brilhante 'O' (cor amarela 11), trilhas variando ate '.' fraco
; cor 11=amarelo, cor 7=prata, cor 8=cinza, cor 15=preto
; valores: cor << 8 | char
; @ = 64, # = 35, * = 42, + = 43, - = 45, . = 46, espaco = 32
donut_pattern: var #32
        static donut_pattern + #0, #2880
        static donut_pattern + #1, #2880
        static donut_pattern + #2, #2880
        static donut_pattern + #3, #2851
        static donut_pattern + #4, #2851
        static donut_pattern + #5, #803
        static donut_pattern + #6, #810
        static donut_pattern + #7, #810
        static donut_pattern + #8, #810
        static donut_pattern + #9, #2091
        static donut_pattern + #10, #2091
        static donut_pattern + #11, #2093
        static donut_pattern + #12, #2093
        static donut_pattern + #13, #2094
        static donut_pattern + #14, #2094
        static donut_pattern + #15, #2080
        static donut_pattern + #16, #2080
        static donut_pattern + #17, #2080
        static donut_pattern + #18, #2094
        static donut_pattern + #19, #2094
        static donut_pattern + #20, #2093
        static donut_pattern + #21, #2093
        static donut_pattern + #22, #2091
        static donut_pattern + #23, #811
        static donut_pattern + #24, #810
        static donut_pattern + #25, #2858
        static donut_pattern + #26, #2858
        static donut_pattern + #27, #2851
        static donut_pattern + #28, #2851
        static donut_pattern + #29, #2851
        static donut_pattern + #30, #2880
        static donut_pattern + #31, #2880

; Novos strings de comandos
str_tetris_cmd: var #7
        static str_tetris_cmd + #0, #'t'
        static str_tetris_cmd + #1, #'e'
        static str_tetris_cmd + #2, #'t'
        static str_tetris_cmd + #3, #'r'
        static str_tetris_cmd + #4, #'i'
        static str_tetris_cmd + #5, #'s'
        static str_tetris_cmd + #6, #0
str_donut_cmd: var #6
        static str_donut_cmd + #0, #'d'
        static str_donut_cmd + #1, #'o'
        static str_donut_cmd + #2, #'n'
        static str_donut_cmd + #3, #'u'
        static str_donut_cmd + #4, #'t'
        static str_donut_cmd + #5, #0
str_invaders_cmd: var #9
        static str_invaders_cmd + #0, #'i'
        static str_invaders_cmd + #1, #'n'
        static str_invaders_cmd + #2, #'v'
        static str_invaders_cmd + #3, #'a'
        static str_invaders_cmd + #4, #'d'
        static str_invaders_cmd + #5, #'e'
        static str_invaders_cmd + #6, #'r'
        static str_invaders_cmd + #7, #'s'
        static str_invaders_cmd + #8, #0

; "INVADERS A/D ESPACO Q=SAIR"  (linha 0, branco)
str_iv_hud: var #27
        static str_iv_hud + #0, #'I'
        static str_iv_hud + #1, #'N'
        static str_iv_hud + #2, #'V'
        static str_iv_hud + #3, #'A'
        static str_iv_hud + #4, #'D'
        static str_iv_hud + #5, #'E'
        static str_iv_hud + #6, #'R'
        static str_iv_hud + #7, #'S'
        static str_iv_hud + #8, #32
        static str_iv_hud + #9, #'A'
        static str_iv_hud + #10, #'/'
        static str_iv_hud + #11, #'D'
        static str_iv_hud + #12, #32
        static str_iv_hud + #13, #'E'
        static str_iv_hud + #14, #'S'
        static str_iv_hud + #15, #'P'
        static str_iv_hud + #16, #'A'
        static str_iv_hud + #17, #'C'
        static str_iv_hud + #18, #'O'
        static str_iv_hud + #19, #32
        static str_iv_hud + #20, #'Q'
        static str_iv_hud + #21, #'='
        static str_iv_hud + #22, #'S'
        static str_iv_hud + #23, #'A'
        static str_iv_hud + #24, #'I'
        static str_iv_hud + #25, #'R'
        static str_iv_hud + #26, #0

str_iv_win: var #8
        static str_iv_win + #0, #'Y'
        static str_iv_win + #1, #'O'
        static str_iv_win + #2, #'U'
        static str_iv_win + #3, #32
        static str_iv_win + #4, #'W'
        static str_iv_win + #5, #'I'
        static str_iv_win + #6, #'N'
        static str_iv_win + #7, #0

str_iv_lose: var #10
        static str_iv_lose + #0, #'G'
        static str_iv_lose + #1, #'A'
        static str_iv_lose + #2, #'M'
        static str_iv_lose + #3, #'E'
        static str_iv_lose + #4, #32
        static str_iv_lose + #5, #'O'
        static str_iv_lose + #6, #'V'
        static str_iv_lose + #7, #'E'
        static str_iv_lose + #8, #'R'
        static str_iv_lose + #9, #0

; VARIAVEIS DE ESTADO
;================================================================
cursor:         var #1
cmd_buf:        var #64

; --- snake state ---
head_idx:       var #1
tail_idx:       var #1
length:         var #1
dir:            var #1
food_pos:       var #1
seed:           var #1
old_head_pos:   var #1
snake_buf:      var #256

; --- tetris state ---
t_board:        var #200
t_cells:        var #8
t_piece:        var #1
t_rot:          var #1
t_x:            var #1
t_y:            var #1
t_seed:         var #1
t_grav:         var #1
t_test_x:       var #1
t_test_y:       var #1
t_drawchar:     var #1

; --- donut state ---
d_angle:        var #1

;================================================================
; DONUT data + state
;================================================================
d_sin_table: var #64
        static d_sin_table + #0, #0
        static d_sin_table + #1, #6
        static d_sin_table + #2, #12
        static d_sin_table + #3, #19
        static d_sin_table + #4, #24
        static d_sin_table + #5, #30
        static d_sin_table + #6, #36
        static d_sin_table + #7, #41
        static d_sin_table + #8, #45
        static d_sin_table + #9, #49
        static d_sin_table + #10, #53
        static d_sin_table + #11, #56
        static d_sin_table + #12, #59
        static d_sin_table + #13, #61
        static d_sin_table + #14, #63
        static d_sin_table + #15, #64
        static d_sin_table + #16, #64
        static d_sin_table + #17, #64
        static d_sin_table + #18, #63
        static d_sin_table + #19, #61
        static d_sin_table + #20, #59
        static d_sin_table + #21, #56
        static d_sin_table + #22, #53
        static d_sin_table + #23, #49
        static d_sin_table + #24, #45
        static d_sin_table + #25, #41
        static d_sin_table + #26, #36
        static d_sin_table + #27, #30
        static d_sin_table + #28, #24
        static d_sin_table + #29, #19
        static d_sin_table + #30, #12
        static d_sin_table + #31, #6
        static d_sin_table + #32, #0
        static d_sin_table + #33, #65530
        static d_sin_table + #34, #65524
        static d_sin_table + #35, #65517
        static d_sin_table + #36, #65512
        static d_sin_table + #37, #65506
        static d_sin_table + #38, #65500
        static d_sin_table + #39, #65495
        static d_sin_table + #40, #65491
        static d_sin_table + #41, #65487
        static d_sin_table + #42, #65483
        static d_sin_table + #43, #65480
        static d_sin_table + #44, #65477
        static d_sin_table + #45, #65475
        static d_sin_table + #46, #65473
        static d_sin_table + #47, #65472
        static d_sin_table + #48, #65472
        static d_sin_table + #49, #65472
        static d_sin_table + #50, #65473
        static d_sin_table + #51, #65475
        static d_sin_table + #52, #65477
        static d_sin_table + #53, #65480
        static d_sin_table + #54, #65483
        static d_sin_table + #55, #65487
        static d_sin_table + #56, #65491
        static d_sin_table + #57, #65495
        static d_sin_table + #58, #65500
        static d_sin_table + #59, #65506
        static d_sin_table + #60, #65512
        static d_sin_table + #61, #65517
        static d_sin_table + #62, #65524
        static d_sin_table + #63, #65530

; Luminance chars: '.,-~:;=!*#$@'  (12 chars, dim → bright)
d_lum_chars: var #12
        static d_lum_chars + #0, #46
        static d_lum_chars + #1, #44
        static d_lum_chars + #2, #45
        static d_lum_chars + #3, #126
        static d_lum_chars + #4, #58
        static d_lum_chars + #5, #59
        static d_lum_chars + #6, #61
        static d_lum_chars + #7, #33
        static d_lum_chars + #8, #42
        static d_lum_chars + #9, #35
        static d_lum_chars + #10, #36
        static d_lum_chars + #11, #64

d_zbuf:    var #1200
d_A:       var #1
d_B:       var #1
d_theta:   var #1
d_phi:     var #1
d_sinA:    var #1
d_cosA:    var #1
d_sinB:    var #1
d_cosB:    var #1
d_sinT:    var #1
d_cosT:    var #1
d_sinP:    var #1
d_cosP:    var #1
d_circx:   var #1
d_circy:   var #1
d_x:       var #1
d_y:       var #1
d_z:       var #1
d_xp:      var #1
d_yp:      var #1
d_idx:     var #1
d_L:       var #1
d_tmp:     var #1

;================================================================
; SPACE INVADERS — estado
;================================================================
iv_ax:        var #1          ; coluna do invasor mais a esquerda
iv_ay:        var #1          ; linha do topo do bloco
iv_adir:      var #1          ; direcao horizontal (+1 / -1)
iv_alive:     var #32         ; 4 linhas x 8 colunas (1=vivo)
iv_count:     var #1          ; invasores vivos
iv_px:        var #1          ; coluna da nave
iv_bx:        var #1          ; coluna do tiro
iv_by:        var #1          ; linha do tiro
iv_bact:      var #1          ; tiro ativo? (1/0)
iv_step:      var #1          ; contador de cadencia do bloco
iv_seed:      var #1          ; RNG (LCG)
iv_apaint:    var #1          ; char usado por i_paint_aliens
iv_dx:        var #1          ; coluna da bomba
iv_dy:        var #1          ; linha da bomba
iv_dact:      var #1          ; bomba ativa? (1/0)
iv_bombcd:    var #1          ; cooldown ate proxima bomba
