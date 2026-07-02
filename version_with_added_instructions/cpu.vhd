-- Processador Versao 4: 06/08/2025
-- Video com 256 cores e tela de 40 colunas por 30 linhas

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.STD_LOGIC_UNSIGNED.all;

entity cpu is
   port (
      clk      : in  STD_LOGIC;
      reset    : in  STD_LOGIC;

      Mem      : in  STD_LOGIC_VECTOR(15 downto 0);
      M5       : out STD_LOGIC_VECTOR(15 downto 0);
      M1       : out STD_LOGIC_VECTOR(15 downto 0);
      RW       : out STD_LOGIC;

      key      : in  STD_LOGIC_VECTOR(7 downto 0);

      videoflag: out STD_LOGIC;
      vga_pos  : out STD_LOGIC_VECTOR(15 downto 0);
      vga_char : out STD_LOGIC_VECTOR(15 downto 0);

      Ponto    : out STD_LOGIC_VECTOR(2 downto 0);

      halt_ack : out STD_LOGIC;
      halt_req : in  STD_LOGIC;

      PC_data  : out STD_LOGIC_VECTOR(15 downto 0);
      break    : out STD_LOGIC
   );
end cpu;

ARCHITECTURE main of cpu is
   TYPE STATES        is (fetch, decode, exec, exec2, halted);                  -- Estados da Maquina de Controle do Processador
   TYPE Registers     is array(0 to 7) of STD_LOGIC_VECTOR(15 downto 0); -- Banco de Registradores
   TYPE LoadRegisters is array(0 to 7) of std_LOGIC;                     -- Sinais de LOAD dos Registradores do Banco

   -- INSTRUCTION SET: 29 INSTRUCTIONS
   -- Data Manipulation Instructions:                                    -- Usage          -- Action        -- Format
   CONSTANT LOAD      : STD_LOGIC_VECTOR(5 downto 0) := "110000";      -- LOAD RX END  -- RX <- M[END]  Format: < inst(6) | RX(3) | xxxxxxx >  + 16bit END
   CONSTANT STORE     : STD_LOGIC_VECTOR(5 downto 0) := "110001";      -- STORE END RX -- M[END] <- RX  Format: < inst(6) | RX(3) | xxxxxxx >  + 16bit END
   CONSTANT LOADIMED  : STD_LOGIC_VECTOR(5 downto 0) := "111000";      -- LOADN RX Nr   -- RX <- Nr       Format: < inst(6) | RX(3) | xxxxxxb0 >  + 16bit Numero
   CONSTANT LOADINDEX : STD_LOGIC_VECTOR(5 downto 0) := "111100";      -- LOADI RX RY   -- RX <- M[RY]   Format: < inst(6) | RX(3) | RY(3) | xxxx >
   CONSTANT STOREINDEX: STD_LOGIC_VECTOR(5 downto 0) := "111101";      -- STOREI RX RY  -- M[RX] <- RY   Format: < inst(6) | RX(3) | RY(3) | xxxx >
   CONSTANT MOV       : STD_LOGIC_VECTOR(5 downto 0) := "110011";      -- MOV RX RY    -- RX <- RY        Format: < inst(6) | RX(3) | RY(3) | xx | x0 >
                                                                        -- MOV RX SP    RX <- SP         Format: < inst(6) | RX(3) | xxx | xx | 01 >
                                                                        -- MOV SP RX    SP <- RX         Format: < inst(6) | RX(3) | xxx | xx | 11 >

   -- I/O Instructions:
   CONSTANT OUTCHAR   : STD_LOGIC_VECTOR(5 downto 0) := "110010";      -- OUTCHAR RX RY -- Video[RY] <- Char(RX)      Format: < inst(6) | RX(3) | RY(3) | xxxx >
                                                                        -- RX contem o codigo do caracter de 0 a 127, sendo que 96 iniciais estao prontos com a tabela ASCII
                                                                        -- RX(6 downto 0) + 32 = Caractere da tabela ASCII - Ver Manual PDF
                                                                        -- RX(10 downto 7) = Cor : 0-branco, 1-marrom, 2-verde, 3-oliva, 4-azul marinho, 5-roxo, 6-teal, 7-prata, 8-cinza, 9-vermelho, 10-lima, 11-amarelo, 12-azul, 13-rosa, 14-aqua, 15-preto
                                                                        -- RY(10 downto 0) = tamanho da tela = 30 linhas x 40 colunas: posicao continua de 0 a 1199 no RY


   CONSTANT INCHAR      : STD_LOGIC_VECTOR(5 downto 0) := "110101";      -- INCHAR RX     -- RX[5..0] <- KeyPressed   RX[15..6] <- 0's     Format: < inst(6) | RX(3) | xxxxxxx >
                                                                        -- Se nao pressionar nenhuma tecla, RX recebe 00FF

   -- Instrucoes novas (modificacao da arquitetura):
   CONSTANT RAND        : STD_LOGIC_VECTOR(5 downto 0) := "110110";      -- RAND RX    -- RX <- numero "aleatorio"   Format: < inst(6) | RX(3) | xxxxxxx >
   CONSTANT RDTIME      : STD_LOGIC_VECTOR(5 downto 0) := "110111";      -- RDTIME RX  -- RX <- tempo em ms          Format: < inst(6) | RX(3) | xxxxxxx >

   CONSTANT ARITH         : STD_LOGIC_VECTOR(1 downto 0) := "10";
   -- Aritmethic Instructions(All should begin wiht "10"):
   CONSTANT ADD          : STD_LOGIC_VECTOR(3 downto 0) := "0000";         -- ADD RX RY RZ / ADDC RX RY RZ     -- RX <- RY + RZ / RX <- RY + RZ + C     -- b0=CarRY              Format: < inst(6) | RX(3) | RY(3) | RZ(3)| C >
   CONSTANT SUB          : STD_LOGIC_VECTOR(3 downto 0) := "0001";         -- SUB RX RY RZ / SUBC RX RY RZ     -- RX <- RY - RZ / RX <- RY - RZ + C     -- b0=CarRY              Format: < inst(6) | RX(3) | RY(3) | RZ(3)| C >
   CONSTANT MULT          : STD_LOGIC_VECTOR(3 downto 0) := "0010";         -- MUL RX RY RZ  / MUL RX RY RZ      -- RX <- RY * RZ / RX <- RY * RZ + C     -- b0=CarRY            Format: < inst(6) | RX(3) | RY(3) | RZ(3)| C >
   CONSTANT DIV          : STD_LOGIC_VECTOR(3 downto 0) := "0011";         -- DIV RX RY RZ                      -- RX <- RY / RZ / RX <- RY / RZ + C     -- b0=CarRY            Format: < inst(6) | RX(3) | RY(3) | RZ(3)| C >
   CONSTANT INC          : STD_LOGIC_VECTOR(3 downto 0) := "0100";         -- INC RX / DEC RX                  -- RX <- RX + 1 / RX <- RX - 1           -- b6= INC/DEC : 0/1   Format: < inst(6) | RX(3) | b6 | xxxxxx >
   CONSTANT LMOD          : STD_LOGIC_VECTOR(3 downto 0) := "0101";         -- MOD RX RY RZ                      -- RX <- RY MOD RZ                                          Format: < inst(6) | RX(3) | RY(3) | RZ(3)| x >

   CONSTANT LOGIC         : STD_LOGIC_VECTOR(1 downto 0) := "01";
   -- LOGIC Instructions (All should begin wiht "01"):
   CONSTANT LAND         : STD_LOGIC_VECTOR(3 downto 0) := "0010";    -- AND RX RY RZ     -- RZ <- RX AND RY   Format: < inst(6) | RX(3) | RY(3) | RZ(3)| x >
   CONSTANT LOR         : STD_LOGIC_VECTOR(3 downto 0) := "0011";      -- OR RX RY RZ      -- RZ <- RX OR RY      Format: < inst(6) | RX(3) | RY(3) | RZ(3)| x >
   CONSTANT LXOR         : STD_LOGIC_VECTOR(3 downto 0) := "0100";    -- XOR RX RY RZ     -- RZ <- RX XOR RY   Format: < inst(6) | RX(3) | RY(3) | RZ(3)| x >
   CONSTANT LNOT         : STD_LOGIC_VECTOR(3 downto 0) := "0101";      -- NOT RX RY          -- RX <- NOT(RY)      Format: < inst(6) | RX(3) | RY(3) | xxxx >
   CONSTANT SHIFT         : STD_LOGIC_VECTOR(3 downto 0) := "0000";      -- SHIFTL0 RX,n / SHIFTL1 RX,n / SHIFTR0 RX,n / SHIFTR1 RX,n / ROTL RX,n / ROTR RX,n
                                                                     -- SHIFT/Rotate RX   -- b6=shif/rotate: 0/1  b5=left/right: 0/1; b4=fill;
                                                                     -- Format: < inst(6) | RX(3) |  b6 b5 b4 | nnnn >

   CONSTANT CMP          : STD_LOGIC_VECTOR(3 downto 0) := "0110";      -- CMP RX RY        -- Compare RX and RY and set FR :   Format: < inst(6) | RX(3) | RY(3) | xxxx >   Flag Register: <...DIVbyZero|StackUnderflow|StackOverflow|DIVByZero|ARITHmeticOverflow|carRY|zero|equal|lesser|greater>
                                                                     -- JMP Condition: (UNconditional, EQual, Not Equal, Zero, Not Zero, CarRY, Not CarRY, GReater, LEsser, Equal or Greater, Equal or Lesser, OVerflow, Not OVerflow, Negative, DIVbyZero, NOT USED)

   -- FLOW CONTROL Instructions:
   CONSTANT JMP         : STD_LOGIC_VECTOR(5 downto 0) := "000010";   -- JMP END    -- PC <- 16bit END                        : b9-b6 = COND      Format: < inst(6) | COND(4) | xxxxxx >   + 16bit END
   CONSTANT CALL         : STD_LOGIC_VECTOR(5 downto 0) := "000011";   -- CALL END   -- M[SP] <- PC | SP-- | PC <- 16bit END   : b9-b6 = COND        Format: < inst(6) | COND(4) | xxxxxx >   + 16bit END
   CONSTANT RTS         : STD_LOGIC_VECTOR(5 downto 0) := "000100";   -- RTS        -- SP++ | PC <- M[SP] | b6=RX/FR: 1/0                          Format: < inst(6) | xxxxxxxxxx >
   CONSTANT PUSH         : STD_LOGIC_VECTOR(5 downto 0) := "000101";   -- PUSH RX / PUSH FR  -- M[SP] <- RX / M[SP] <- FR | SP--     : b6=RX/FR: 0/1      Format: < inst(6) | RX(3) | b6 | xxxxxx >
   CONSTANT POP         : STD_LOGIC_VECTOR(5 downto 0) := "000110";   -- POP RX  / POP FR   -- SP++ | RX <- M[SP]  / FR <- M[SP]    : b6=RX/FR: 0/1      Format: < inst(6) | RX(3) | b6 | xxxxxx >


   -- Control Instructions:
   CONSTANT NOP         : STD_LOGIC_VECTOR(5 downto 0) := "000000";   -- NOP            -- Do Nothing                               Format: < inst(6) | xxxxxxxxxx >
   CONSTANT HALT         : STD_LOGIC_VECTOR(5 downto 0) := "001111";   -- HALT           -- StOP Here                              Format: < inst(6) | xxxxxxxxxx >
   CONSTANT SETC         : STD_LOGIC_VECTOR(5 downto 0) := "001000";   -- CLEARC / SETC  -- Set/Clear CarRY: b9 = 1-set; 0-clear   Format: < inst(6) | b9 | xxxxxxxxx >
   CONSTANT BREAKP      : STD_LOGIC_VECTOR(5 downto 0) := "001110";    -- BREAK POINT    -- Switch to manual clock                  Format: < inst(6) | xxxxxxxxxx >


   -- CONSTANTes para controle do Mux2: Estes sinais selecionam as respectivas entradas para o Mux2
   CONSTANT sULA      : STD_LOGIC_VECTOR (2 downto 0) := "000";
   CONSTANT sMem      : STD_LOGIC_VECTOR (2 downto 0) := "001";
   CONSTANT sM4      : STD_LOGIC_VECTOR (2 downto 0) := "010";
   CONSTANT sTECLADO   : STD_LOGIC_VECTOR (2 downto 0) := "011"; -- nao tinha
   CONSTANT sSP      : STD_LOGIC_VECTOR (2 downto 0) := "100";


   -- Sinais para o Processo da ULA
   signal OP            : STD_LOGIC_VECTOR(6 downto 0);   -- OP(6) deve ser setado para OPeracoes com carRY
   signal x, y, result   : STD_LOGIC_VECTOR(15 downto 0);
   signal FR            : STD_LOGIC_VECTOR(15 downto 0);   -- Flag Register: <...DIVbyZero|StackUnderflow|StackOverflow|DIVByZero|ARITHmeticOverflow|carRY|zero|equal|lesser|greater>
   signal auxFR         : STD_LOGIC_VECTOR(15 downto 0);   -- Representa um barramento conectando a ULA ao Mux6 para escrever no FR


begin

-- Maquina de Controle
process(clk, reset)

   --Register Declaration:
   variable PC      : STD_LOGIC_VECTOR(15 downto 0);      -- Program Counter
   variable IR      : STD_LOGIC_VECTOR(15 downto 0);      -- Instruction Register
   variable SP      : STD_LOGIC_VECTOR(15 downto 0);      -- Stack Pointer
   variable MAR   : STD_LOGIC_VECTOR(15 downto 0);      -- Memory address Register
   VARIABLE   TECLADO   :STD_LOGIC_VECTOR(15 downto 0);      -- Registrador para receber dados do teclado -- nao tinha

   -- Novas variaveis para as instrucoes RAND e RDTIME
   variable Aleatorio   : STD_LOGIC_VECTOR(15 downto 0);     -- contador que anda 1 por clock; lido em instantes imprevisiveis vira um "aleatorio"
   variable PreMili     : STD_LOGIC_VECTOR(15 downto 0);     -- conta clocks ate' fechar 1 milissegundo
   variable Milis       : STD_LOGIC_VECTOR(15 downto 0);     -- tempo em milissegundos desde que ligou

   variable reg : Registers;

   -- Mux dos barramentos de dados internos
   VARIABLE   M2            :STD_LOGIC_VECTOR(15 downto 0);   -- Mux dos barramentos de dados internos para os Registradores
   VARIABLE M3, M4      :STD_LOGIC_VECTOR(15 downto 0);   -- Mux dos Registradores para as entradas da ULA
   VARIABLE   M6            :STD_LOGIC_VECTOR(15 downto 0);   -- Mux do Flag Register

   -- Novos Sinais da Versao 2: Controle dos registradores internos (Load-Inc-Dec)
   variable LoadReg      : LoadRegisters;
   variable LoadIR      : std_LOGIC;
   variable LoadMAR      : std_LOGIC;
   variable LoadPC      : std_LOGIC;
   variable IncPC       : std_LOGIC;
   VARIABLE LoadSP      : STD_LOGIC;
   variable IncSP       : std_LOGIC;
   variable DecSP         : std_LOGIC;
   variable LoadFR      : std_LOGIC;

   -- Selecao dos Mux 2 e 6
   variable selM2       : STD_LOGIC_VECTOR(2 downto 0);
   variable selM6       : STD_LOGIC_VECTOR(2 downto 0);

   VARIABLE BreakFlag   : STD_LOGIC;  -- Para sinalizar a mudanca para Clock manual/Clock Automatico para  a nova instrucao Break

   variable state : STATES;  -- Estados do processador: fetch, decode, exec, halted

   -- Seletores dos registradores para execussao das instrucoes
   variable RX : integer;
   variable RY : integer;
   variable RZ : integer;


begin

   if(reset = '1') then

      state := fetch;      -- inicializa o estado na busca!
      M1(15 downto 0) <=   x"0000";  -- inicializa na linha Zero da memoria -> Programa tem que comecar na linha Zero !!
      videoflag <= '0';

      RX := 0;
      RY := 0;
      RZ := 0;

      RW <= '0';

      LoadIR   := '0';
      LoadMAR   := '0';
      LoadPC   := '0';
      IncPC      := '0';
      IncSP      := '0';
      DecSP      := '0';
      LoadSP   := '0';
      LoadFR   := '0';
      selM2      := sMem;
      selM6      := sULA;

      LoadReg(0) := '0';
      LoadReg(1) := '0';
      LoadReg(2) := '0';
      LoadReg(3) := '0';
      LoadReg(4) := '0';
      LoadReg(5) := '0';
      LoadReg(6) := '0';
      LoadReg(7) := '0';

      REG(0)  := x"0000";
      REG(1)  := x"0000";
      REG(2)  := x"0000";
      REG(3)  := x"0000";
      REG(4)  := x"0000";
      REG(5)  := x"0000";
      REG(6)  := x"0000";
      REG(7)  := x"0000";

      PC := x"0000";  -- inicializa na linha Zero da memoria -> Programa tem que comecar na linha Zero !!
      SP := x"7ffc";  -- Inicializa a Pilha no final da mem�ria: 7ffc
      IR := x"0000";
      MAR := x"0000";

      -- Zera o "aleatorio" e o relogio de milissegundos
      Aleatorio := x"0000";
      PreMili   := x"0000";
      Milis     := x"0000";

       BreakFlag:= '0';   -- Break Point Flag
       BREAK <= '0';    -- Break Point output to switch to manual clock

       -- Novo na Versao 3
      HALT_ack <= '0';

   elsif(clk'event and clk = '1') then

      if(LoadIR = '1')   then IR := Mem;             end if;

      if(LoadPC = '1')   then PC := Mem;             end if;

      if(IncPC = '1')   then PC := PC + x"0001";    end if;

      if(LoadMAR = '1') then MAR := Mem;             end if;

      if(LoadSP = '1')    then SP := M4;             end if;

      if(IncSP = '1')   then SP := SP + x"0001";    end if;

      if(DecSP = '1')   then SP := SP - x"0001";    end if;

      -- O contador "aleatorio" anda 1 a cada clock, sempre.
      Aleatorio := Aleatorio + x"0001";

      -- Relogio: conta clocks; a cada 12000 (1 ms num clock de 12 MHz) soma 1 ms.
      PreMili := PreMili + x"0001";
      if(PreMili = 12000) then
         PreMili := x"0000";
         Milis := Milis + x"0001";
      end if;

      -- Selecao do Mux6
      if (selM6 = sULA) THEN M6 := auxFR;            -- Sempre recebe flags da ULA
      ELSIF (selM6 = sMem) THEN M6 := Mem; END IF;   -- A menos que seja POP FR, quando recebe da Memoria

      -- So' carrega o FR quando for Pop FR, Cmp, aritmethic, ou logic.
      if(LoadFR = '1')    then FR <= M6;             end if;


      -- Atualiza o nome dos registradores!!!
      RX := conv_integer(IR(9 downto 7));
      RY := conv_integer(IR(6 downto 4));
      RZ := conv_integer(IR(3 downto 1));

      -- Selecao do Mux2
      if (selM2 = sULA)       THEN M2 := RESULT;
      ELSIF (selM2 = sMem)    THEN M2 := Mem;
      ELSIF (selM2 = sM4)       THEN M2 := M4;
      ELSIF (selM2 = sTECLADO)THEN M2 := TECLADO;
      ELSIF (selM2 = sSP)       THEN M2 := SP;
      END IF;

      -- Carrega dados do Mux 2 para os registradores
      if(LoadReg(RX) = '1') then reg(RX) := M2; end if;

      -- Reseta os sinais de controle APOS usa-los acima
      -- Zera todos os sinais de controle, para depois ligar um por um nas instrucoes a medida que for necessario: a ultima atribuicao e' a que vale no processo!!!
      LoadIR  := '0';
      LoadMAR := '0';
      LoadPC  := '0';
      IncPC   := '0';
      IncSP   := '0';
      DecSP   := '0';
      LoadSP  := '0';
      LoadFR  := '0';
      selM6     := sULA;   -- Sempre atualiza o FR da ULA, a nao ser que a instrucao seja POP FR

      LoadReg(0) := '0';
      LoadReg(1) := '0';
      LoadReg(2) := '0';
      LoadReg(3) := '0';
      LoadReg(4) := '0';
      LoadReg(5) := '0';
      LoadReg(6) := '0';
      LoadReg(7) := '0';

      videoflag <= '0';   -- Abaixa o sinal para a "Placa de Video" : sobe a cada OUTCHAR

      RW <= '0';  -- Sinal de Letura/Ecrita da mem�ria em Leitura  (0 - ler, 1 - escrever)

      -- Novo na Versao 3
      if(halt_req = '1') then state := halted; end if;

      -- Novo na Versao 3: para escrever PC no LCD da placa
      PC_data <= PC;

      case state is
--************************************************************************
-- FETCH STATE
--************************************************************************

      when fetch =>
         PONTO <= "001";

         -- Inicio das acoes do ciclo de Busca !!
         M1 <= PC;
         RW <= '0';
         LoadIR := '1';
         IncPC := '1';

         STATE := decode;

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

--************************************************************************
-- DECODE STATE
--************************************************************************
      when decode =>
         PONTO <= "010";

--========================================================================
-- INCHAR           RX[7..0] <- KeyPressed   RX[15..8] <- 0
--========================================================================
         IF(IR(15 DOWNTO 10) = INCHAR) THEN -- Se nenhuma tecla for pressionada no momento da leitura, Rx <- x"00FF"

            TECLADO(7 downto 0) := key(7 downto 0);
            TECLADO(15 downto 8) := X"00";

            selM2 := sTECLADO;
            LoadReg(RX) := '1';
            state := fetch;
         END IF;

--========================================================================
-- RAND RX     RX <- numero "aleatorio" (o contador que anda todo clock)
--========================================================================
         IF(IR(15 DOWNTO 10) = RAND) THEN
            M4 := Aleatorio;      -- pega o valor atual do contador
            selM2 := sM4;         -- manda pelo Mux4/Mux2 (mesmo caminho do MOV RX RY)
            LoadReg(RX) := '1';   -- RX <- aleatorio
            state := fetch;
         END IF;

--========================================================================
-- RDTIME RX   RX <- tempo em milissegundos desde que ligou
--========================================================================
         IF(IR(15 DOWNTO 10) = RDTIME) THEN
            M4 := Milis;          -- pega o relogio em ms
            selM2 := sM4;         -- mesmo caminho do MOV RX RY
            LoadReg(RX) := '1';   -- RX <- tempo
            state := fetch;
         END IF;

--========================================================================
-- OUTCHAR         Video[RY] <- Char(RX)
--========================================================================
         IF(IR(15 DOWNTO 10) = OUTCHAR) THEN
            M3 := Reg(Rx);                      -- M3 <- Rx
            M4 := Reg(Ry);                      -- M4 <- Ry

            -- Este bloco troca a cor do preto pelo branco: agora a cor "0000" = Branco !
            if M3(15 downto 8) = "00000000" then
               M3(15 downto 8) := "11111111";
            end if;

            vga_char <= M3; --vga_char   <= M3  : C�digo do Character vem do Rx via M3
            vga_pos   <= M4;  --  Posicao na tela do Character vem do Ry via M4
            videoflag <= '1';  -- Sobe o videoflag para gravar o charactere na mem�ria de video
            state := fetch;
         END IF;

--========================================================================
-- LOAD Imediato          RX <- Nr
--========================================================================
         IF(IR(15 DOWNTO 10) = LOADIMED) THEN
            M1 <= PC;            -- M1 <- PC
            Rw <= '0';            -- Rw <= '0'
            selM2 := sMeM;       -- M2 <- MEM
            LoadReg(RX) := '1';   -- LRx <- 1
            IncPC := '1';        -- IncPC <- 1
            state := fetch;
         END IF;


--========================================================================
-- LOAD Direto           RX <- M[End]
--========================================================================
         IF(IR(15 DOWNTO 10) = LOAD) THEN -- Busca o endereco
            M1 <= PC;            -- endereca a 2a palavra da instrucao (o END)
            Rw <= '0';           -- Leitura
            LoadMAR := '1';      -- MAR <- Mem = END
            IncPC := '1';        -- avanca o PC para depois do END
            state := exec;  -- Vai para o estado de Executa para buscar o dado do endereco
         END IF;



--========================================================================
-- STORE   DIReto         M[END] <- RX
--========================================================================
         IF(IR(15 DOWNTO 10) = STORE) THEN  -- Busca o endereco
            M1 <= PC;            -- endereca a 2a palavra da instrucao (o END)
            Rw <= '0';           -- Leitura do END
            LoadMAR := '1';      -- MAR <- Mem = END
            IncPC := '1';        -- avanca o PC para depois do END
            state := exec;  -- Vai para o estado de Executa para gravar Registrador no endereco
         END IF;

--========================================================================
-- LOAD Indexado por registrador          RX <- M(RY)
--========================================================================
         IF(IR(15 DOWNTO 10) = LOADINDEX) THEN
            -- LOADI RX RY : RX <- M[RY]. Endereca a memoria com o conteudo de RY
            -- e grava o dado lido em RX (mesmo padrao de leitura do LOADIMED).
            M1 <= Reg(RY);       -- M1 <- RY (endereco)
            Rw <= '0';           -- Leitura
            selM2 := sMem;       -- M2 <- MEM
            LoadReg(RX) := '1';  -- RX <- M[RY]
            state := fetch;
         END IF;

--========================================================================
-- STORE indexado por registrador          M[RX] <- RY
--========================================================================
         IF(IR(15 DOWNTO 10) = STOREINDEX) THEN
            -- STOREI RX RY : M[RX] <- RY. Endereca a memoria com RX e escreve RY.
            M1 <= Reg(RX);       -- M1 <- RX (endereco)
            M5 <= Reg(RY);       -- M5 <- RY (dado a gravar)
            Rw <= '1';           -- Escrita
            state := fetch;
         END IF;




--========================================================================
-- MOV           RX/SP <- RY/SP

-- MOV RX RY    RX <- RY           Format: < inst(6) | RX(3) | RY(3) | xx | x0 >
-- MOV RX SP    RX <- SP         Format: < inst(6) | RX(3) | xxx | xx | 01 >
-- MOV SP RX    SP <- RX         Format: < inst(6) | RX(3) | xxx | xx | 11 >

--========================================================================
         IF(IR(15 DOWNTO 10) = MOV) THEN
            -- Os 2 bits menos significativos (IR(1..0)) distinguem as 3 variantes:
            IF(IR(0) = '0') THEN         -- "x0" : MOV RX RY -> RX <- RY
               M4 := Reg(RY);            -- passa RY pelo Mux4...
               selM2 := sM4;             -- ...e seleciona M4 no Mux2
               LoadReg(RX) := '1';       -- RX <- RY
            ELSIF(IR(1) = '0') THEN      -- "01" : MOV RX SP -> RX <- SP
               selM2 := sSP;             -- M2 <- SP
               LoadReg(RX) := '1';       -- RX <- SP
            ELSE                          -- "11" : MOV SP RX -> SP <- RX
               M4 := Reg(RX);            -- M4 <- RX
               LoadSP := '1';            -- SP <- M4 (=RX)
            END IF;
            state := fetch;
         END IF;

--========================================================================
-- ARITH OPERATION ('INC' NOT INCLUDED)          RX <- RY (?) RZ
--========================================================================
         IF(IR(15 DOWNTO 14) = ARITH AND IR(13 DOWNTO 10) /= INC) THEN
            -- ADD/SUB/MULT/DIV/MOD RX RY RZ : RX <- RY (op) RZ, via ULA.
            -- Nao calcula a conta "na mao": aciona a ULA com OP/x/y e deixa
            -- a propria ULA gerar RESULT e as flags (auxFR).
            OP(6) <= IR(0);               -- b0 = usa Carry (ADDC/SUBC)
            OP(5 downto 4) <= ARITH;      -- prefixo aritmetico "10"
            OP(3 downto 0) <= IR(13 downto 10); -- sub-opcode (ADD/SUB/...)
            x <= Reg(RY);                 -- operando 1 = RY
            y <= Reg(RZ);                 -- operando 2 = RZ
            selM2 := sULA;                -- M2 <- RESULT da ULA
            LoadReg(RX) := '1';           -- RX <- resultado
            LoadFR := '1';                -- atualiza o Flag Register
            state := fetch;
         END IF;

--========================================================================
-- INC/DEC         RX <- RX (+ or -) 1
--========================================================================
         IF(IR(15 DOWNTO 14) = ARITH AND (IR(13 DOWNTO 10) = INC))   THEN
            -- INC/DEC RX : RX <- RX +/- 1. Reaproveita a ULA (ADD/SUB) com y=1.
            -- b6 (IR(6)) decide: 0 = INC, 1 = DEC.
            OP(6) <= '0';                 -- sem carry
            OP(5 downto 4) <= ARITH;      -- prefixo aritmetico "10"
            IF(IR(6) = '0') THEN
               OP(3 downto 0) <= ADD;     -- INC : RX <- RX + 1
            ELSE
               OP(3 downto 0) <= SUB;     -- DEC : RX <- RX - 1
            END IF;
            x <= Reg(RX);                 -- operando = proprio RX
            y <= x"0001";                 -- constante 1
            selM2 := sULA;                -- M2 <- RESULT da ULA
            LoadReg(RX) := '1';           -- RX <- resultado
            LoadFR := '1';                -- atualiza o Flag Register
            state := fetch;
         END IF;

--========================================================================
-- LOGIC OPERATION ('SHIFT', and 'CMP'  NOT INCLUDED)           RX <- RY (?) RZ
--========================================================================
         IF(IR(15 DOWNTO 14) = LOGIC AND IR(13 DOWNTO 10) /= SHIFT AND IR(13 DOWNTO 10) /= CMP) THEN
            -- AND/OR/XOR RX RY RZ : RX <- RY (op) RZ ; NOT RX RY : RX <- not RY.
            -- Tudo via ULA (bloco LOGIC), que ja trata o NOT usando apenas x.
            OP(6) <= '0';
            OP(5 downto 4) <= LOGIC;      -- prefixo logico "01"
            OP(3 downto 0) <= IR(13 downto 10); -- sub-opcode (AND/OR/XOR/NOT)
            x <= Reg(RY);                 -- operando 1 = RY (unico usado no NOT)
            y <= Reg(RZ);                 -- operando 2 = RZ
            selM2 := sULA;                -- M2 <- RESULT da ULA
            LoadReg(RX) := '1';           -- RX <- resultado
            LoadFR := '1';                -- atualiza o Flag Register (bit zero)
            state := fetch;
         END IF;


--========================================================================
-- SHIFT      RX, RY     RX  <- SHIFT[ RY]        ROTATE INCluded !
--========================================================================
         IF(IR(15 DOWNTO 14) = LOGIC and (IR(13 DOWNTO 10) = SHIFT)) THEN
            if(IR(6 DOWNTO 4) = "000") then       -- SHIFT LEFT 0
               Reg(RX) := To_StdLOGICVector(to_bitvector(Reg(RY))sll conv_integer(IR(3 DOWNTO 0)));
            elsif(IR(6 DOWNTO 4) = "001") then   -- SHIFT LEFT 1
               Reg(RX) := not (To_StdLOGICVector(to_bitvector(not Reg(RY))sll conv_integer(IR(3 DOWNTO 0))));
            elsif(IR(6 DOWNTO 4) = "010") then   -- SHIFT RIGHT 0
               Reg(RX) := To_StdLOGICVector(to_bitvector(Reg(RY))srl conv_integer(IR(3 DOWNTO 0)));
            elsif(IR(6 DOWNTO 4) = "011") then   -- SHIFT RIGHT 0
               Reg(RX) := not (To_StdLOGICVector(to_bitvector(not Reg(RY))srl conv_integer(IR(3 DOWNTO 0))));
            elsif(IR(6 DOWNTO 5) = "11") then   -- ROTATE RIGHT
               Reg(RX) := To_StdLOGICVector(to_bitvector(Reg(RY))ror conv_integer(IR(3 DOWNTO 0)));
            elsif(IR(6 DOWNTO 5) = "10") then   -- ROTATE LEFT
               Reg(RX) := To_StdLOGICVector(to_bitvector(Reg(RY))rol conv_integer(IR(3 DOWNTO 0)));
            end if;

            state := fetch;
         end if;


--========================================================================
-- CMP      RX, RY
--========================================================================
         IF(IR(15 DOWNTO 14) = LOGIC AND IR(13 DOWNTO 10) = CMP) THEN
            -- CMP RX RY : compara RX e RY e atualiza o FR (greater/lesser/equal).
            -- NAO escreve em registrador (nao liga LoadReg).
            OP(5 downto 4) <= LOGIC;      -- prefixo logico "01"
            OP(3 downto 0) <= CMP;        -- sub-opcode de comparacao
            x <= Reg(RX);                 -- operando 1 = RX
            y <= Reg(RY);                 -- operando 2 = RY
            LoadFR := '1';                -- so atualiza o Flag Register
            state := fetch;
         END IF;

--========================================================================
-- JMP END    PC <- 16bit END : b9-b6 = COND
-- Flag Register: <...Negative|StackUnderflow|StackOverflow|DIVByZero|ARITHmeticOverflow|carRY|zero|equal|lesser|greater>
-- JMP Condition: (UNconditional, EQual, Not Equal, Zero, Not Zero, CarRY, Not CarRY, GReater, LEsser, Equal or Greater, Equal or Lesser, OVerflow, Not OVerflow, Negative, DIVbyZero, NOT USED)
--========================================================================
         IF(IR(15 DOWNTO 10) = JMP) THEN
            IF((IR(9 DOWNTO 6) = "0000") OR
            ((IR(9 DOWNTO 6) = "0111") AND FR(0) = '1') OR
            ((IR(9 DOWNTO 6) = "1001") AND (FR(2) = '1' OR FR(0) = '1')) OR
            ((IR(9 DOWNTO 6) = "1000") AND FR(1) = '1') OR
            ((IR(9 DOWNTO 6) = "1010") AND (FR(2) = '1' OR FR(1) = '1')) OR
            ((IR(9 DOWNTO 6) = "0001") AND FR(2) = '1') OR
            ((IR(9 DOWNTO 6) = "0010") AND FR(2) = '0') OR
            ((IR(9 DOWNTO 6) = "0011") AND FR(3) = '1') OR
            ((IR(9 DOWNTO 6) = "0100") AND FR(3) = '0') OR
            ((IR(9 DOWNTO 6) = "0101") AND FR(4) = '1') OR
            ((IR(9 DOWNTO 6) = "0110") AND FR(4) = '0') OR
            ((IR(9 DOWNTO 6) = "1011") AND FR(5) = '1') OR
            ((IR(9 DOWNTO 6) = "1100") AND FR(5) = '0') OR
            ((IR(9 DOWNTO 6) = "1101") AND FR(6) = '1') OR
            ((IR(9 DOWNTO 6) = "1110") AND FR(9) = '1')) THEN
               M1 <= PC;            -- M1 <- PC
               Rw <= '0';            -- Rw <= '0'
               LoadPC := '1';         -- LoadPC <- 1

            ELSE
               IncPC := '1';
            END IF;

            state := fetch;
         END IF;

--========================================================================
-- CALL END    PC <- 16bit END : b9-b6 = COND PUSH(PC)
-- Flag Register: <...Negative|StackUnderflow|StackOverflow|DIVByZero|ARITHmeticOverflow|carRY|zero|equal|lesser|greater>
-- JMP Condition: (UNconditional, EQual, Not Equal, Zero, Not Zero, CarRY, Not CarRY, GReater, LEsser, Equal or Greater, Equal or Lesser, OVerflow, Not OVerflow, Negative, DIVbyZero, NOT USED)
--========================================================================
         IF(IR(15 DOWNTO 10) = CALL) THEN
            -- Mesmas condicoes b9..b6 do JMP. Se a condicao for verdadeira,
            -- empilha o endereco de retorno (instrucao apos o END) e vai ao
            -- estado exec para desviar (PC <- END). Se falsa, so pula o END.
            IF((IR(9 DOWNTO 6) = "0000") OR
            ((IR(9 DOWNTO 6) = "0111") AND FR(0) = '1') OR
            ((IR(9 DOWNTO 6) = "1001") AND (FR(2) = '1' OR FR(0) = '1')) OR
            ((IR(9 DOWNTO 6) = "1000") AND FR(1) = '1') OR
            ((IR(9 DOWNTO 6) = "1010") AND (FR(2) = '1' OR FR(1) = '1')) OR
            ((IR(9 DOWNTO 6) = "0001") AND FR(2) = '1') OR
            ((IR(9 DOWNTO 6) = "0010") AND FR(2) = '0') OR
            ((IR(9 DOWNTO 6) = "0011") AND FR(3) = '1') OR
            ((IR(9 DOWNTO 6) = "0100") AND FR(3) = '0') OR
            ((IR(9 DOWNTO 6) = "0101") AND FR(4) = '1') OR
            ((IR(9 DOWNTO 6) = "0110") AND FR(4) = '0') OR
            ((IR(9 DOWNTO 6) = "1011") AND FR(5) = '1') OR
            ((IR(9 DOWNTO 6) = "1100") AND FR(5) = '0') OR
            ((IR(9 DOWNTO 6) = "1101") AND FR(6) = '1') OR
            ((IR(9 DOWNTO 6) = "1110") AND FR(9) = '1')) THEN
               M1 <= SP;              -- endereca o topo da pilha
               M5 <= PC + x"0001";    -- empilha o retorno (PC aponta p/ END; +1)
               Rw <= '1';             -- escreve na pilha
               DecSP := '1';          -- SP-- (a pilha cresce para baixo)
               state := exec;         -- exec faz PC <- END
            ELSE
               IncPC := '1';          -- condicao falsa: pula a palavra do END
               state := fetch;
            END IF;
         END IF;

--========================================================================
-- RTS          PC <- Mem[SP]
--========================================================================
         IF(IR(15 DOWNTO 10) = RTS) THEN
            -- RTS : SP++ | PC <- M[SP]. Primeiro incrementa o SP; a leitura
            -- de M[SP] acontece em exec/exec2.
            IncSP := '1';        -- SP++ (desfaz o DecSP do CALL)
            state := exec;
         END IF;

--========================================================================
-- PUSH RX
--========================================================================
         IF(IR(15 DOWNTO 10) = PUSH) THEN
            -- PUSH : M[SP] <- (RX ou FR) ; SP--. b6 (IR(6)): 0 = RX, 1 = FR.
            M1 <= SP;               -- endereca o topo da pilha
            IF(IR(6) = '0') THEN
               M5 <= Reg(RX);       -- empilha RX
            ELSE
               M5 <= FR;            -- empilha o Flag Register
            END IF;
            Rw <= '1';              -- escreve na pilha
            DecSP := '1';           -- SP-- (pilha cresce para baixo)
            state := fetch;
         END IF;

--========================================================================
-- POP RX
--========================================================================
         IF(IR(15 DOWNTO 10) = POP) THEN
            -- POP : SP++ | (RX ou FR) <- M[SP]. Primeiro incrementa o SP;
            -- a leitura de M[SP] e a gravacao acontecem em exec.
            IncSP := '1';        -- SP++
            state := exec;
         END IF;

--========================================================================
-- NOP
--========================================================================
         IF( IR(15 DOWNTO 10) = NOP) THEN
            state := fetch;
         end if;

--========================================================================
-- HALT
--========================================================================
         IF( IR(15 DOWNTO 10) = HALT) THEN
            state := halted;
         END IF;

--========================================================================
-- SETC/CLEARC
--========================================================================
         IF( IR(15 DOWNTO 10) = SETC) THEN
            FR(4) <= IR(9);  -- Bit 9 define se vai ser SET ou CLEAR
            state := fetch;
         end if;

--========================================================================
-- BREAKP
--========================================================================
         IF( IR(15 DOWNTO 10) = BREAKP) THEN
            BreakFlag := not(BreakFlag);  -- Troca entre clock manual e clock autom�tico
            BREAK <= BreakFlag;
            state := fetch;
            PONTO <= "101";
         END IF;

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX













--************************************************************************
-- EXECUTE STATE
--************************************************************************

         when exec =>
            PONTO <= "100";
--========================================================================
-- EXEC LOAD DIReto           RX <- M[END]
--========================================================================
         IF(IR(15 DOWNTO 10) = LOAD) THEN
            -- MAR ja contem o END (carregado no decode). Le M[END] em RX.
            M1 <= MAR;           -- endereca o dado
            Rw <= '0';           -- Leitura
            selM2 := sMem;       -- M2 <- MEM
            LoadReg(RX) := '1';  -- RX <- M[END]
            state := fetch;
         END IF;

--========================================================================
-- EXEC STORE DIReto          M[END] <- RX
--========================================================================
         IF(IR(15 DOWNTO 10) = STORE) THEN
            -- MAR ja contem o END (carregado no decode). Grava RX em M[END].
            M1 <= MAR;           -- endereca o destino
            M5 <= Reg(RX);       -- dado a gravar = RX
            Rw <= '1';           -- Escrita
            state := fetch;
         END IF;


--========================================================================
-- EXEC CALL    Pilha <- PC e PC <- 16bit END :
--========================================================================
         IF(IR(15 DOWNTO 10) = CALL) THEN
            -- O retorno ja foi empilhado no decode. Agora desvia: PC <- END,
            -- lendo a 2a palavra da instrucao (PC ainda aponta para ela).
            M1 <= PC;            -- endereca a palavra do END
            Rw <= '0';           -- Leitura
            LoadPC := '1';       -- PC <- Mem = END
            state := fetch;
         END IF;

--========================================================================
-- EXEC RTS          PC <- Mem[SP]
--========================================================================
         IF(IR(15 DOWNTO 10) = RTS) THEN
            -- SP ja foi incrementado no decode. Endereca M[SP] para ler o
            -- endereco de retorno; a carga do PC ocorre em exec2.
            M1 <= SP;            -- endereca o topo da pilha
            Rw <= '0';           -- Leitura
            state := exec2;
         END IF;

--========================================================================
-- EXEC POP RX/FR
--========================================================================
         IF(IR(15 DOWNTO 10) = POP) THEN
            -- SP ja foi incrementado no decode. Le M[SP] para RX ou FR.
            M1 <= SP;            -- endereca o topo da pilha
            Rw <= '0';           -- Leitura
            IF(IR(6) = '0') THEN
               selM2 := sMem;       -- M2 <- MEM
               LoadReg(RX) := '1';  -- RX <- M[SP]
            ELSE
               selM6 := sMem;       -- Mux6 recebe da memoria
               LoadFR := '1';       -- FR <- M[SP]
            END IF;
            state := fetch;
         END IF;

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

--************************************************************************
-- EXECUTE2 STATE
--************************************************************************

         when exec2 =>
            PONTO <= "100";
--========================================================================
-- EXEC2 RTS          PC <- Mem[SP]
--========================================================================
         IF(IR(15 DOWNTO 10) = RTS) THEN
            -- Mem ja traz M[SP] (endereco de retorno), pois M1<=SP foi feito
            -- em exec. Carrega o PC com esse valor.
            M1 <= SP;            -- mantem o endereco estavel
            Rw <= '0';           -- Leitura
            LoadPC := '1';       -- PC <- Mem = M[SP] (retorno)
            state := fetch;
         END IF;

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


--************************************************************************
-- HALT STATE
--************************************************************************
      WHEN halted =>
         PONTO <= "111";
         state := halted;
         halt_ack <= '1';

      WHEN OTHERS =>
         state := fetch;
         videoflag <= '0';
         PONTO <= "000";

      END CASE;

   end if;
   end process;




--************************************************************************
-- ULA --->  3456  (3042)
--************************************************************************
PROCESS (OP, X, Y, reset)

   VARIABLE AUX      : STD_LOGIC_VECTOR(15 downto 0);
   VARIABLE RESULT32 : STD_LOGIC_VECTOR(31 downto 0);

BEGIN

   IF (reset = '1') THEN
      auxFR <= x"0000";
      RESULT <= x"0000";
   else
      auxFR <= FR;

--========================================================================
-- ARITH
--========================================================================
      IF (OP (5 downto 4) = ARITH) THEN
         CASE OP (3 downto 0) IS
            WHEN ADD =>
               IF (OP(6) = '1') THEN --Soma com carRY
                  AUX := X + Y + FR(4);
                  RESULT32 := (x"00000000" + X + Y + FR(4));
               ELSE  --Soma sem carRY
                  AUX := X + Y;
                  RESULT32 := (x"00000000" + X + Y);
               end if;
               if(RESULT32 > "01111111111111111") THEN -- CarRY
                  auxFR(4) <= '1';
               ELSE
                  auxFR(4) <= '0';
               end if;

            WHEN SUB =>
               AUX := X - Y;

            WHEN MULT =>
               RESULT32 := X * Y;
               AUX := RESULT32(15 downto 0);
               if(RESULT32 > x"0000FFFF") THEN -- ARITHmetic Overflow
                  auxFR(5) <= '1';
               ELSE
                  auxFR(5) <= '0';
               end if;

            WHEN DIV =>
               IF(Y = x"0000") THEN
                  AUX := x"0000";
                  auxFR(6) <= '1'; -- DIV by Zero
               ELSE
                  AUX := CONV_STD_LOGIC_VECTOR(CONV_INTEGER(X)/CONV_INTEGER(Y), 16);
                  auxFR(6) <= '0';
               END IF;
            WHEN LMOD =>
               IF(Y = x"0000") THEN
                  AUX := x"0000";
                  auxFR(6) <= '1'; -- DIV by Zero
               ELSE
                  AUX := CONV_STD_LOGIC_VECTOR(CONV_INTEGER(X) mod CONV_INTEGER(Y), 16);
                  auxFR(6) <= '0';
               END IF;
            WHEN others =>   -- invalid operation, defaults to nothing
               AUX := X;
         END CASE;
         if(AUX = x"0000") THEN
            auxFR(3) <= '1';  -- FR = <...|zero|equal|lesser|greater>
         ELSE
            auxFR(3) <= '0';  -- FR = <...|zero|equal|lesser|greater>
         end if;
         if(AUX < x"0000") THEN   -- NEGATIVO
            auxFR(9) <= '1';
         ELSE
            auxFR(9) <= '0';
         end if;
         RESULT <= AUX;

      ELSIF (OP (5 downto 4) = LOGIC) THEN
         IF (OP (3 downto 0) = CMP) THEN
            result <= x;
            IF (x > y) THEN
               auxFR(2 downto 0) <= "001"; -- FR = <...|zero|equal|lesser|greater>
            ELSIF (x < y) THEN
               auxFR(2 downto 0) <= "010"; -- FR = <...|zero|equal|lesser|greater>
            ELSIF (x = y) THEN
               auxFR(2 downto 0) <= "100"; -- FR = <...|zero|equal|lesser|greater>
            END IF;
         ELSE
            CASE OP (3 downto 0) IS
               WHEN LAND => result <= x and y;

               WHEN LXOR => result <= x xor y;

               WHEN LOR =>    result <= x or y;

               WHEN LNOT => result <= not x;

               WHEN others =>   -- invalid operation, defaults to nothing
                  RESULT <= X;
            END CASE;
            if(result = x"0000") THEN
               auxFR(3) <= '1';  -- FR = <...|zero|equal|lesser|greater>
            ELSE
               auxFR(3) <= '0';  -- FR = <...|zero|equal|lesser|greater>
            end if;
         END IF;
      END IF;
   END IF; -- Reset
END PROCESS;
end main;
