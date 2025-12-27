# nes

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
