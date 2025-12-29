# one OK

```bash

#!/usr/bin/env python3
import os
import time
import xml.etree.ElementTree as ET
import pygame
import subprocess
import sys
import fcntl  # Importante para impedir scripts duplicados

# --- Caminhos Configuráveis ---
BASE_DIR = '/userdata/system/.dev'
SOM_COIN = os.path.join(BASE_DIR, 'efeitos_sonoros/coins.mp3')
ARQ_COUNT = os.path.join(BASE_DIR, 'contador.txt')
ARQ_CONTADOR = os.path.join(BASE_DIR, '.contador.txt')
ARQ_TEMPO = os.path.join(BASE_DIR, 'tempo_jogo.txt')
ES_INPUT_CFG = os.path.join(BASE_DIR, 'es_input.cfg')
ARQ_COIN = os.path.join(BASE_DIR, 'coin')
LOCK_FILE = '/tmp/script_coin.lock' # Arquivo de trava para impedir duplicação

TEMPO_JOGO_MINUTOS = 2

# --- Funções Auxiliares ---
def garantir_instancia_unica():
    """ Garante que apenas um script rode por vez usando fcntl """
    try:
        global lock_file_handle
        lock_file_handle = open(LOCK_FILE, 'w')
        # Tenta bloquear o arquivo. Se falhar, é porque já tem outro script rodando.
        fcntl.lockf(lock_file_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        print("[ERRO] O script já está em execução! Encerrando duplicata.")
        sys.exit(0)

def tocar_som(path):
    try:
        subprocess.Popen(['mpv', '--no-video', '--really-quiet', path],
                         stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"[ERRO] Falha ao tocar som: {e}")

def ler_arquivo(caminho, padrao=0):
    if not os.path.exists(caminho):
        return padrao
    try:
        with open(caminho, 'r') as f:
            return int(f.read().strip())
    except:
        return padrao

def escrever_arquivo(caminho, valor):
    try:
        with open(caminho, 'w') as f:
            f.write(str(valor))
    except Exception as e:
        print(f"[ERRO] Escrevendo em {caminho}: {e}")

def incrementar_arquivo(caminho, quanto=1):
    valor = ler_arquivo(caminho)
    escrever_arquivo(caminho, valor + quanto)

def decrementar_arquivo(caminho, quanto=1):
    valor = ler_arquivo(caminho)
    novo_valor = max(0, valor - quanto)
    escrever_arquivo(caminho, novo_valor)

def exibir_status():
    count = ler_arquivo(ARQ_COUNT)
    contador = ler_arquivo(ARQ_CONTADOR)
    tempo = ler_arquivo(ARQ_TEMPO)
    print(f"📊 Créditos: {count} | Acumulado: {contador} | Tempo de jogo: {tempo}s")

def carregar_ids():
    select_ids = {}
    r3_ids = {}
    if not os.path.exists(ES_INPUT_CFG):
        print(f"[ERRO] Arquivo '{ES_INPUT_CFG}' não encontrado. Usando padrão.")
        select_ids['usb gamepad'] = 8
        r3_ids['usb gamepad'] = 11
        return select_ids, r3_ids

    try:
        tree = ET.parse(ES_INPUT_CFG)
        root = tree.getroot()
        for inputConfig in root.findall('inputConfig'):
            name = inputConfig.attrib.get('deviceName', '').strip().lower()
            for inp in inputConfig.findall('input'):
                inp_name = inp.attrib.get('name').lower()
                if inp_name == 'select':
                    select_ids[name] = int(inp.attrib.get('id'))
                elif inp_name == 'r3':
                    r3_ids[name] = int(inp.attrib.get('id'))
    except Exception as e:
        print(f"[ERRO] Parsing XML: {e}")
    return select_ids, r3_ids

def incrementar_contador():
    valor_atual = ler_arquivo(ARQ_CONTADOR) 
    novo_valor = valor_atual + 1 
    escrever_arquivo(ARQ_CONTADOR, novo_valor) 
    print(f"[SELECT] Contador incrementado: {valor_atual} -> {novo_valor}")

# --- Loop Principal ---
def main():
    # 1. Bloqueia duplicatas logo no início
    garantir_instancia_unica()

    pygame.init()
    pygame.joystick.init()

    select_ids, r3_ids = carregar_ids()
    joysticks_map = {}
    last_joy_count = -1
    
    # Variáveis para Debounce (Evitar clique duplo rápido demais)
    last_select_time = 0
    DEBOUNCE_DELAY = 0.3  # Tempo mínimo entre coins (em segundos)
    
    print("[INIT] Script iniciado e travado (Single Instance).")

    while True:
        num_joysticks = pygame.joystick.get_count()
        if num_joysticks != last_joy_count:
            joysticks_map.clear()
            for i in range(num_joysticks):
                js = pygame.joystick.Joystick(i)
                js.init()
                name = js.get_name().strip().lower()
                select_id = select_ids.get(name)
                r3_id = r3_ids.get(name)
                if select_id is not None or r3_id is not None:
                    joysticks_map[i] = {
                        'obj': js,
                        'name': name,
                        'select_id': select_id,
                        'r3_id': r3_id,
                        'r3_press_time': None,
                        'r3_executado': False
                    }
                    print(f"[INFO] Joystick detectado: {name}")
                else:
                    print(f"[AVISO] Joystick '{name}' não mapeado.")
            last_joy_count = num_joysticks

        for event in pygame.event.get():
            if event.type == pygame.JOYBUTTONDOWN:
                idx = event.joy
                if idx in joysticks_map:
                    js_data = joysticks_map[idx]
                    
                    # --- Lógica do R3 (Sair) ---
                    if event.button == js_data['r3_id']:
                        js_data['r3_press_time'] = time.time()
                        js_data['r3_executado'] = False

                    # --- Lógica do SELECT (Crédito) ---
                    elif event.button == js_data['select_id']:
                        current_time = time.time()
                        # Verifica se passou tempo suficiente desde o último clique (Debounce)
                        if (current_time - last_select_time) > DEBOUNCE_DELAY:
                            last_select_time = current_time # Atualiza o tempo do último clique
                            
                            if os.path.exists(ARQ_COIN):
                                incrementar_arquivo(ARQ_CONTADOR)
                                print("[SELECT] Coin detectado: Incrementando apenas .contador.txt sem som.")
                            else:
                                if os.path.exists(ARQ_TEMPO):
                                    print("[SELECT] Incrementando tempo.")
                                    incrementar_arquivo(ARQ_TEMPO, TEMPO_JOGO_MINUTOS * 60)
                                else:
                                    print("[SELECT] Incrementando créditos.")
                                    incrementar_arquivo(ARQ_COUNT)
                                
                                incrementar_contador()
                                tocar_som(SOM_COIN)
                            
                            exibir_status()
                        else:
                            print("[IGNORE] Clique muito rápido (Debounce).")

            elif event.type == pygame.JOYBUTTONUP:
                idx = event.joy
                if idx in joysticks_map:
                    js_data = joysticks_map[idx]
                    if event.button == js_data['r3_id']:
                        press_time = js_data.get('r3_press_time')
                        if press_time and not js_data['r3_executado']:
                            duracao = time.time() - press_time
                            # Se for toque rápido no R3 (Menos de 1s)
                            if duracao < 1.0:
                                count = ler_arquivo(ARQ_COUNT)
                                if count > 0:
                                    if os.path.exists(ARQ_TEMPO):
                                        decrementar_arquivo(ARQ_COUNT)
                                        incrementar_arquivo(ARQ_TEMPO, TEMPO_JOGO_MINUTOS * 60)
                                        tocar_som(SOM_COIN)
                                        print(f"[R3] Créditos -> Tempo. Restam: {count - 1}")
                                    elif os.path.exists(ARQ_COIN):
                                        decrementar_arquivo(ARQ_COUNT)
                                        print("[R3] Coin mode: simulando tecla 62.")
                                        subprocess.run(["xdotool", "keydown", "62"])
                                        time.sleep(0.1)
                                        subprocess.run(["xdotool", "keyup", "62"])
                                    else:
                                        print("[R3] Nada a fazer (arquivos de controle ausentes).")
                                else:
                                    print("[R3] Sem créditos disponíveis.")
                                exibir_status()
                        js_data['r3_press_time'] = None
                        js_data['r3_executado'] = False

        # Verificação contínua de pressão longa (sem soltar)
        for js_data in joysticks_map.values():
            r3_id = js_data['r3_id']
            press_time = js_data['r3_press_time']
            if r3_id is not None and press_time and not js_data['r3_executado']:
                # Verifica se o botão ainda está pressionado
                try:
                    if js_data['obj'].get_button(r3_id):
                        duracao = time.time() - press_time
                        if duracao >= 1.0:
                            print("[R3] Pressão longa detectada. Fechando jogo.")
                            subprocess.run(["xdotool", "key", "Alt+F4"])
                            subprocess.run(["rm", "-f", "/userdata/system/.dev/tempo_jogo.txt"])
                            subprocess.run(["rm", "-f", "/userdata/system/.dev/coin"])

                            js_data['r3_executado'] = True
                            js_data['r3_press_time'] = None
                            exibir_status()
                except pygame.error:
                    # Joystick pode ter sido desconectado
                    pass

        time.sleep(0.01)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[SAÍDA] Encerrando...")
    finally:
        pygame.quit()
````
# emulatorlauncher 40

  ```bash

        #!/bin/bash
cp -f /userdata/system/.dev/es_input.cfg /userdata/system/configs/emulationstation/
SAVE_ROOT="/userdata/saves"
find "$SAVE_ROOT" -type f -regex '.*\.state[0-9]$' | while read -r file; do
    dir=$(dirname "$file")
    base=$(basename "$file")
    game="${base%%.state*}"

    # Lista apenas saves reais do jogo, ignorando PNG ou .auto
    saves=( $(ls -1t "$dir"/"$game".state[0-9] 2>/dev/null) )
    [[ ${#saves[@]} -eq 0 ]] && continue

    newest="${saves[0]}"
    auto_file="$dir/$game.state.auto"

    # Mantém o mais recente como .auto
    if [[ -f "$auto_file" ]]; then
        if [[ "$newest" -nt "$auto_file" ]]; then
            mv -f "$newest" "$auto_file"
        else
            newest="$auto_file"
        fi
    else
        mv -f "$newest" "$auto_file"
    fi

    # Apaga os outros antigos
    for old in "${saves[@]}"; do
        [[ "$old" != "$newest" ]] && rm -f "$old"
    done
done

rm -f /userdata/system/configs/retroarch/retroarchcustom.cfg

####################################################################
# 1. VERIFICAÇÃO DE SALDO (GATEKEEPER)
# O jogo (Arcade ou Console) só abre se o contador for maior que 0.
####################################################################

# Verifica se o arquivo contador existe
if [ -f /userdata/system/.dev/contador.txt ]; then
    # Lê o valor atual
    count=$(cat /userdata/system/.dev/contador.txt)
    
    # Se o saldo for 0 ou menor, BLOQUEIA TUDO.
    if [ "$count" -le 0 ]; then
        echo "Saldo zerado ($count). O jogo não será iniciado."
        Launcher_off.sh
        mpv /userdata/system/.dev/efeitos_sonoros/insert_coin.wav
        exit 0
    fi
else
    echo "Arquivo contador.txt não encontrado! Bloqueando por segurança."
    exit 1
fi

# Se chegou aqui, o usuário TEM crédito. Agora decidimos como tratar.

####################################################################
# 2. VERIFICAÇÃO DE SISTEMAS ARCADE (MODO FICHA)
# Apenas roda o jogo. NÃO altera o contador.txt.
####################################################################

if [[ "$@" == *"atomiswave"* ]] || \
   [[ "$@" == *"fbalpha"* ]] || \
   [[ "$@" == *"fbneo"* ]] || \
   [[ "$@" == *"mame"* ]] || \
   [[ "$@" == *"naomi"* ]]; then

    echo "Sistema Arcade detectado. Cliente possui saldo. Liberando acesso sem descontar crédito inicial."

    # Cria o arquivo coin para sinalizar modo ficha (se o emulador usar isso)
    echo "" >> /userdata/system/.dev/coin
    
    # Roda o emulador
    /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py "$@"
    
    # Limpeza Botões
    Launcher_off.sh

    # Limpeza ao fechar
    rm -f /userdata/system/.dev/coin
    
    # Encerra o script aqui. Saldo permanece intacto.
    exit 0
fi

####################################################################
# 3. LÓGICA PARA CONSOLES (MODO TEMPO)
# Desconta 1 crédito e inicia o temporizador.
####################################################################

echo "Sistema Console detectado. Descontando 1 crédito..."

# Desconta 1 crédito do contador
count=$(($count - 1))
echo "$count" > /userdata/system/.dev/contador.txt
echo "Novo saldo: $count"

# Configuração de Tempo
CAMINHO_COIN="/usr/bin/one"

# Tenta ler o tempo configurado, se falhar usa 15 minutos padrão
if [ -f "$CAMINHO_COIN" ]; then
    TEMPO_JOGO_MINUTOS=$(grep -oP 'TEMPO_JOGO_MINUTOS\s*=\s*\K\d+' "$CAMINHO_COIN")
    if [ -z "$TEMPO_JOGO_MINUTOS" ]; then TEMPO_JOGO_MINUTOS=15; fi
else
    TEMPO_JOGO_MINUTOS=15
fi

TEMPO_JOGO_SEGUNDOS=$((TEMPO_JOGO_MINUTOS * 60))

echo "Tempo definido: $TEMPO_JOGO_MINUTOS minutos."
echo "$TEMPO_JOGO_SEGUNDOS" > /userdata/system/.dev/tempo_jogo.txt

# Inicia o jogo em background
/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py "$@" &
game_pid=$!

# Inicia o overlay
python3.14 /usr/bin/two &

####################################################################
# FUNÇÕES DE CONTROLE (LOOP DE TEMPO)
####################################################################

# Função para matar o emulador quando o tempo se esgota
kill_emulador() {
    xdotool key alt+F4
    sleep 0.5
    xdotool key alt+F4
}

# Função que decrementa o tempo de jogo a cada segundo
decrementa_tempo_jogo() {
    local file_path="/userdata/system/.dev/tempo_jogo.txt"
    local tempo_atual=0

    sleep 2.5
    
    while true; do
        # Verifica se o arquivo tempo_jogo.txt ainda existe
        if [ ! -f "$file_path" ]; then
            break
        fi

        # Lê o valor de tempo_jogo.txt a cada segundo
        tempo_atual=$(cat "$file_path")

        # Valida se o valor lido é um número
        if ! [[ "$tempo_atual" =~ ^[0-9]+$ ]]; then
            sleep 1
            continue
        fi

        # Se o tempo ainda for maior que 0, decrementa o valor
        if [ "$tempo_atual" -gt 0 ]; then
            tempo_atual=$((tempo_atual - 1))
            echo "$tempo_atual" > "$file_path"  # Atualiza o valor no arquivo
        else
            echo "Tempo esgotado!"
            kill_emulador  # Finaliza o emulador
            rm -f "$file_path"  # Remove o arquivo de tempo
            break
        fi

        sleep 1  # Aguarda 1 segundo antes de fazer a próxima verificação
    done
}

# Roda o contador de tempo
decrementa_tempo_jogo &

# Aguarda o jogo fechar (seja por tempo ou pelo usuário)
wait $game_pid

# Limpeza final
if [ -f /userdata/system/.dev/contador.txt.bkp ]; then
    mv /userdata/system/.dev/contador.txt.bkp /userdata/system/.dev/contador.txt
fi
Launcher_off.sh
exit 0

``` 

# emulatorlauncher 42

```bash

#!/bin/bash
cp -f /userdata/system/.dev/es_input.cfg /userdata/system/configs/emulationstation/
SAVE_ROOT="/userdata/saves"
find "$SAVE_ROOT" -type f -regex '.*\.state[0-9]$' | while read -r file; do
    dir=$(dirname "$file")
    base=$(basename "$file")
    game="${base%%.state*}"

    # Lista apenas saves reais do jogo, ignorando PNG ou .auto
    saves=( $(ls -1t "$dir"/"$game".state[0-9] 2>/dev/null) )
    [[ ${#saves[@]} -eq 0 ]] && continue

    newest="${saves[0]}"
    auto_file="$dir/$game.state.auto"

    # Mantém o mais recente como .auto
    if [[ -f "$auto_file" ]]; then
        if [[ "$newest" -nt "$auto_file" ]]; then
            mv -f "$newest" "$auto_file"
        else
            newest="$auto_file"
        fi
    else
        mv -f "$newest" "$auto_file"
    fi

    # Apaga os outros antigos
    for old in "${saves[@]}"; do
        [[ "$old" != "$newest" ]] && rm -f "$old"
    done
done

rm -f /userdata/system/configs/retroarch/retroarchcustom.cfg

####################################################################
# 1. VERIFICAÇÃO DE SALDO (GATEKEEPER)
# O jogo (Arcade ou Console) só abre se o contador for maior que 0.
####################################################################

# Verifica se o arquivo contador existe
if [ -f /userdata/system/.dev/contador.txt ]; then
    # Lê o valor atual
    count=$(cat /userdata/system/.dev/contador.txt)
    
    # Se o saldo for 0 ou menor, BLOQUEIA TUDO.
    if [ "$count" -le 0 ]; then
        echo "Saldo zerado ($count). O jogo não será iniciado."
        Launcher_off.sh
        mpv /userdata/system/.dev/efeitos_sonoros/insert_coin.wav
        exit 0
    fi
else
    echo "Arquivo contador.txt não encontrado! Bloqueando por segurança."
    exit 1
fi

# Se chegou aqui, o usuário TEM crédito. Agora decidimos como tratar.

####################################################################
# 2. VERIFICAÇÃO DE SISTEMAS ARCADE (MODO FICHA)
# Apenas roda o jogo. NÃO altera o contador.txt.
####################################################################

if [[ "$@" == *"atomiswave"* ]] || \
   [[ "$@" == *"fbalpha"* ]] || \
   [[ "$@" == *"fbneo"* ]] || \
   [[ "$@" == *"mame"* ]] || \
   [[ "$@" == *"naomi"* ]]; then

    echo "Sistema Arcade detectado. Cliente possui saldo. Liberando acesso sem descontar crédito inicial."

    # Cria o arquivo coin para sinalizar modo ficha (se o emulador usar isso)
    echo "" >> /userdata/system/.dev/coin
    
    # Roda o emulador
    /usr/bin/es "$@"
    
    # Limpeza Botões
    Launcher_off.sh

    # Limpeza ao fechar
    rm -f /userdata/system/.dev/coin
    
    # Encerra o script aqui. Saldo permanece intacto.
    exit 0
fi

####################################################################
# 3. LÓGICA PARA CONSOLES (MODO TEMPO)
# Desconta 1 crédito e inicia o temporizador.
####################################################################

echo "Sistema Console detectado. Descontando 1 crédito..."

# Desconta 1 crédito do contador
count=$(($count - 1))
echo "$count" > /userdata/system/.dev/contador.txt
echo "Novo saldo: $count"

# Configuração de Tempo
CAMINHO_COIN="/usr/bin/one"

# Tenta ler o tempo configurado, se falhar usa 15 minutos padrão
if [ -f "$CAMINHO_COIN" ]; then
    TEMPO_JOGO_MINUTOS=$(grep -oP 'TEMPO_JOGO_MINUTOS\s*=\s*\K\d+' "$CAMINHO_COIN")
    if [ -z "$TEMPO_JOGO_MINUTOS" ]; then TEMPO_JOGO_MINUTOS=15; fi
else
    TEMPO_JOGO_MINUTOS=15
fi

TEMPO_JOGO_SEGUNDOS=$((TEMPO_JOGO_MINUTOS * 60))

echo "Tempo definido: $TEMPO_JOGO_MINUTOS minutos."
echo "$TEMPO_JOGO_SEGUNDOS" > /userdata/system/.dev/tempo_jogo.txt

# Inicia o jogo em background
/usr/bin/es "$@" &
game_pid=$!

# Inicia o overlay
python3.14 /usr/bin/two &

####################################################################
# FUNÇÕES DE CONTROLE (LOOP DE TEMPO)
####################################################################

# Função para matar o emulador quando o tempo se esgota
kill_emulador() {
    xdotool key alt+F4
    sleep 0.5
    xdotool key alt+F4
}

# Função que decrementa o tempo de jogo a cada segundo
decrementa_tempo_jogo() {
    local file_path="/userdata/system/.dev/tempo_jogo.txt"
    local tempo_atual=0

    sleep 2.5
    
    while true; do
        # Verifica se o arquivo tempo_jogo.txt ainda existe
        if [ ! -f "$file_path" ]; then
            break
        fi

        # Lê o valor de tempo_jogo.txt a cada segundo
        tempo_atual=$(cat "$file_path")

        # Valida se o valor lido é um número
        if ! [[ "$tempo_atual" =~ ^[0-9]+$ ]]; then
            sleep 1
            continue
        fi

        # Se o tempo ainda for maior que 0, decrementa o valor
        if [ "$tempo_atual" -gt 0 ]; then
            tempo_atual=$((tempo_atual - 1))
            echo "$tempo_atual" > "$file_path"  # Atualiza o valor no arquivo
        else
            echo "Tempo esgotado!"
            kill_emulador  # Finaliza o emulador
            rm -f "$file_path"  # Remove o arquivo de tempo
            break
        fi

        sleep 1  # Aguarda 1 segundo antes de fazer a próxima verificação
    done
}

# Roda o contador de tempo
decrementa_tempo_jogo &

# Aguarda o jogo fechar (seja por tempo ou pelo usuário)
wait $game_pid

# Limpeza final
if [ -f /userdata/system/.dev/contador.txt.bkp ]; then
    mv /userdata/system/.dev/contador.txt.bkp /userdata/system/.dev/contador.txt
fi
Launcher_off.sh
exit 0

```

# nes

```bash
libretroConfig.py >> udev >> '"x"'

libretroRetroarchCustom.py


atomiswave
fbalpha
fbneo
mame
naomi


 >> libretroConfig.py

    # Autosave option
    if system.isOptSet('autosave') and system.getOptBoolean('autosave') == True:
        retroarchConfig['savestate_auto_save'] = 'false'
        retroarchConfig['savestate_auto_load'] = 'true'
    else:
        retroarchConfig['savestate_auto_save'] = 'false'
        retroarchConfig['savestate_auto_load'] = 'true'

# emulatorlauncher > /usr/bin/emulatorlauncher

```bash

#!/bin/bash

SAVE_ROOT="/userdata/saves"
find "$SAVE_ROOT" -type f -regex '.*\.state[0-9]$' | while read -r file; do
    dir=$(dirname "$file")
    base=$(basename "$file")
    game="${base%%.state*}"

    # Lista apenas saves reais do jogo, ignorando PNG ou .auto
    saves=( $(ls -1t "$dir"/"$game".state[0-9] 2>/dev/null) )
    [[ ${#saves[@]} -eq 0 ]] && continue

    newest="${saves[0]}"
    auto_file="$dir/$game.state.auto"

    # Mantém o mais recente como .auto
    if [[ -f "$auto_file" ]]; then
        if [[ "$newest" -nt "$auto_file" ]]; then
            mv -f "$newest" "$auto_file"
        else
            newest="$auto_file"
        fi
    else
        mv -f "$newest" "$auto_file"
    fi

    # Apaga os outros antigos
    for old in "${saves[@]}"; do
        [[ "$old" != "$newest" ]] && rm -f "$old"
    done
done

rm -f /userdata/system/configs/retroarch/retroarchcustom.cfg

####################################################################
# 1. VERIFICAÇÃO DE SALDO (GATEKEEPER)
# O jogo (Arcade ou Console) só abre se o contador for maior que 0.
####################################################################

# Verifica se o arquivo contador existe
if [ -f /userdata/system/.dev/contador.txt ]; then
    # Lê o valor atual
    count=$(cat /userdata/system/.dev/contador.txt)
    
    # Se o saldo for 0 ou menor, BLOQUEIA TUDO.
    if [ "$count" -le 0 ]; then
        echo "Saldo zerado ($count). O jogo não será iniciado."
        exit 0
    fi
else
    echo "Arquivo contador.txt não encontrado! Bloqueando por segurança."
    exit 1
fi

# Se chegou aqui, o usuário TEM crédito. Agora decidimos como tratar.

####################################################################
# 2. VERIFICAÇÃO DE SISTEMAS ARCADE (MODO FICHA)
# Apenas roda o jogo. NÃO altera o contador.txt.
####################################################################

if [[ "$@" == *"atomiswave"* ]] || \
   [[ "$@" == *"fbalpha"* ]] || \
   [[ "$@" == *"fbneo"* ]] || \
   [[ "$@" == *"mame"* ]] || \
   [[ "$@" == *"naomi"* ]]; then

    echo "Sistema Arcade detectado. Cliente possui saldo. Liberando acesso sem descontar crédito inicial."

    # Cria o arquivo coin para sinalizar modo ficha (se o emulador usar isso)
    echo "" >> /userdata/system/.dev/coin
    
    # Roda o emulador
    /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py "$@"
    
    # Limpeza ao fechar
    rm -f /userdata/system/.dev/coin
    
    # Encerra o script aqui. Saldo permanece intacto.
    exit 0
fi

####################################################################
# 3. LÓGICA PARA CONSOLES (MODO TEMPO)
# Desconta 1 crédito e inicia o temporizador.
####################################################################

echo "Sistema Console detectado. Descontando 1 crédito..."

# Desconta 1 crédito do contador
count=$(($count - 1))
echo "$count" > /userdata/system/.dev/contador.txt
echo "Novo saldo: $count"

# Configuração de Tempo
CAMINHO_COIN="/usr/bin/one"

# Tenta ler o tempo configurado, se falhar usa 15 minutos padrão
if [ -f "$CAMINHO_COIN" ]; then
    TEMPO_JOGO_MINUTOS=$(grep -oP 'TEMPO_JOGO_MINUTOS\s*=\s*\K\d+' "$CAMINHO_COIN")
    if [ -z "$TEMPO_JOGO_MINUTOS" ]; then TEMPO_JOGO_MINUTOS=15; fi
else
    TEMPO_JOGO_MINUTOS=15
fi

TEMPO_JOGO_SEGUNDOS=$((TEMPO_JOGO_MINUTOS * 60))

echo "Tempo definido: $TEMPO_JOGO_MINUTOS minutos."
echo "$TEMPO_JOGO_SEGUNDOS" > /userdata/system/.dev/tempo_jogo.txt

# Inicia o jogo em background
/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py "$@" &
game_pid=$!

# Inicia o overlay
python3.14 /usr/bin/two &

####################################################################
# FUNÇÕES DE CONTROLE (LOOP DE TEMPO)
####################################################################

kill_emulador() {
    xdotool key alt+F4
    sleep 0.5
    xdotool key alt+F4
}

decrementa_tempo_jogo() {
    local file_path="/userdata/system/.dev/tempo_jogo.txt"
    local tempo_atual=0

    sleep 2.5
    
    while true; do
        if [ ! -f "$file_path" ]; then break; fi
        
        tempo_atual=$(cat "$file_path")
        
        # Validação se é número
        if ! [[ "$tempo_atual" =~ ^[0-9]+$ ]]; then sleep 1; continue; fi

        if [ "$tempo_atual" -gt 0 ]; then
            tempo_atual=$((tempo_atual - 1))
            echo "$tempo_atual" > "$file_path"
        else
            echo "Tempo esgotado!"
            kill_emulador
            rm -f "$file_path"
            break
        fi
        sleep 1
    done
}

# Roda o contador
decrementa_tempo_jogo &

# Aguarda o jogo fechar (seja por tempo ou pelo usuário)
wait $game_pid

# Limpeza final
if [ -f /userdata/system/.dev/contador.txt.bkp ]; then
    mv /userdata/system/.dev/contador.txt.bkp /userdata/system/.dev/contador.txt
fi

exit 0

```




# v40
# libretroConfig.py > /usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py

```bash

#!/bin/bash

# Caminhos dos arquivos
ARQUIVO_CONFIG="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py"
ARQUIVO_CUSTOM="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroRetroarchCustom.py"

echo "--- Script V5: Bloqueio Total de Notificações ---"

# 1. Permite escrita
mount -o remount,rw /

# 2. Backups (Se não existirem)
[ ! -f "$ARQUIVO_CONFIG.bak" ] && cp "$ARQUIVO_CONFIG" "$ARQUIVO_CONFIG.bak"
[ ! -f "$ARQUIVO_CUSTOM.bak" ] && cp "$ARQUIVO_CUSTOM" "$ARQUIVO_CUSTOM.bak"

# ---------------------------------------------------------
# PARTE A: libretroConfig.py (Lógica do Sistema)
# ---------------------------------------------------------
echo "[Config] Aplicando SaveState forçado e Input Driver..."
sed -i "s/retroarchConfig\['savestate_auto_load'\] = 'false'/retroarchConfig['savestate_auto_load'] = 'true'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_joypad_driver'\] = 'udev'/retroarchConfig['input_joypad_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_driver'\] = 'udev'/retroarchConfig['input_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"

# ---------------------------------------------------------
# PARTE B: libretroRetroarchCustom.py (O Arquivo Gerador)
# ---------------------------------------------------------
echo "[Custom] Aplicando Hotkey e removendo Fonte..."
# Hotkey null
sed -i "/'input_enable_hotkey'/ s/\"shift\"/\"null\"/" "$ARQUIVO_CUSTOM"
# Fonte de video false (Texto OSD)
sed -i "/'video_font_enable'/ s/\"true\"/\"false\"/" "$ARQUIVO_CUSTOM"

# ---------------------------------------------------------
# PARTE C: INJEÇÃO DE NOVAS CONFIGURAÇÕES (WIDGETS)
# ---------------------------------------------------------
echo "[Custom] Injetando bloqueio de Widgets..."

# Função para inserir linha se ela não existir
inserir_se_nao_existir() {
    FILE=$1
    SEARCH=$2  # Texto âncora (onde inserir depois)
    CHECK=$3   # Texto para verificar se já existe
    INSERT=$4  # A linha exata a ser inserida

    if grep -q "$CHECK" "$FILE"; then
        echo "  -> Configuração '$CHECK' já existe. Pulando injeção."
        # Se já existe, garante que está como false
        sed -i "/'$CHECK'/ s/\"true\"/\"false\"/" "$FILE"
    else
        echo "  -> Injetando '$CHECK'..."
        # Insere APÓS a linha do texto âncora
        sed -i "/$SEARCH/a \    $INSERT" "$FILE"
    fi
}

# 1. Desligar Widgets (As notificações gráficas/bolhas)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "menu_enable_widgets" \
    "retroarchSettings.save('menu_enable_widgets', '\"false\"')"

# 2. Desligar especificamente notificação de SAVE state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_save_state" \
    "retroarchSettings.save('notification_show_save_state', '\"false\"')"

# 3. Desligar especificamente notificação de LOAD state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_load_state" \
    "retroarchSettings.save('notification_show_load_state', '\"false\"')"

# 4. Desligar notificação de Config Loaded (mensagem chata de início)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_config_override_load" \
    "retroarchSettings.save('notification_show_config_override_load', '\"false\"')"

echo "--- Verificação Final ---"
grep "menu_enable_widgets" "$ARQUIVO_CUSTOM"
grep "notification_show_save_state" "$ARQUIVO_CUSTOM"

echo "--- Concluído! Reinicie o jogo. ---"


```


# v42 Configs retroarch

```

#!/bin/bash

# Caminhos dos arquivos
#ARQUIVO_CONFIG="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py"
#ARQUIVO_CUSTOM="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroRetroarchCustom.py"
ARQUIVO_CONFIG="/usr/lib/python3.12/site-packages/configgen/generators/libretro/libretroConfig.py"
ARQUIVO_CUSTOM="/usr/lib/python3.12/site-packages/configgen/generators/libretro/libretroRetroarchCustom.py"

echo "--- Script V5: Bloqueio Total de Notificações ---"

# 1. Permite escrita
mount -o remount,rw /

# 2. Backups (Se não existirem)
[ ! -f "$ARQUIVO_CONFIG.bak" ] && cp "$ARQUIVO_CONFIG" "$ARQUIVO_CONFIG.bak"
[ ! -f "$ARQUIVO_CUSTOM.bak" ] && cp "$ARQUIVO_CUSTOM" "$ARQUIVO_CUSTOM.bak"

# ---------------------------------------------------------
# PARTE A: libretroConfig.py (Lógica do Sistema)
# ---------------------------------------------------------
echo "[Config] Aplicando SaveState forçado e Input Driver..."
sed -i "s/retroarchConfig\['savestate_auto_load'\] = 'false'/retroarchConfig['savestate_auto_load'] = 'true'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_joypad_driver'\] = 'udev'/retroarchConfig['input_joypad_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_driver'\] = 'udev'/retroarchConfig['input_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"

# ---------------------------------------------------------
# PARTE B: libretroRetroarchCustom.py (O Arquivo Gerador)
# ---------------------------------------------------------
echo "[Custom] Aplicando Hotkey e removendo Fonte..."
# Hotkey null
sed -i "/'input_enable_hotkey'/ s/\"shift\"/\"null\"/" "$ARQUIVO_CUSTOM"
# Fonte de video false (Texto OSD)
sed -i "/'video_font_enable'/ s/\"true\"/\"false\"/" "$ARQUIVO_CUSTOM"

# ---------------------------------------------------------
# PARTE C: INJEÇÃO DE NOVAS CONFIGURAÇÕES (WIDGETS)
# ---------------------------------------------------------
echo "[Custom] Injetando bloqueio de Widgets..."

# Função para inserir linha se ela não existir
inserir_se_nao_existir() {
    FILE=$1
    SEARCH=$2  # Texto âncora (onde inserir depois)
    CHECK=$3   # Texto para verificar se já existe
    INSERT=$4  # A linha exata a ser inserida

    if grep -q "$CHECK" "$FILE"; then
        echo "  -> Configuração '$CHECK' já existe. Pulando injeção."
        # Se já existe, garante que está como false
        sed -i "/'$CHECK'/ s/\"true\"/\"false\"/" "$FILE"
    else
        echo "  -> Injetando '$CHECK'..."
        # Insere APÓS a linha do texto âncora
        sed -i "/$SEARCH/a \    $INSERT" "$FILE"
    fi
}

# 1. Desligar Widgets (As notificações gráficas/bolhas)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "menu_enable_widgets" \
    "retroarchSettings.save('menu_enable_widgets', '\"false\"')"

# 2. Desligar especificamente notificação de SAVE state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_save_state" \
    "retroarchSettings.save('notification_show_save_state', '\"false\"')"

# 3. Desligar especificamente notificação de LOAD state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_load_state" \
    "retroarchSettings.save('notification_show_load_state', '\"false\"')"

# 4. Desligar notificação de Config Loaded (mensagem chata de início)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_config_override_load" \
    "retroarchSettings.save('notification_show_config_override_load', '\"false\"')"

echo "--- Verificação Final ---"
grep "menu_enable_widgets" "$ARQUIVO_CUSTOM"
grep "notification_show_save_state" "$ARQUIVO_CUSTOM"

echo "--- Concluído! Reinicie o jogo. ---"

````
