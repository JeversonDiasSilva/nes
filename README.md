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





# libretroConfig.py > /usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py

```bash
#!/bin/bash

# Caminhos dos arquivos
ARQUIVO_CONFIG="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py"
ARQUIVO_CUSTOM="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroRetroarchCustom.py"

echo "--- Iniciando Script de Modificação Completo (V4) ---"

# 1. Permite escrita
echo "[1/6] Liberando permissão de escrita..."
mount -o remount,rw /

# 2. Backups (Só faz se ainda não existirem para não sobrescrever o backup original limpo)
echo "[2/6] Verificando backups..."
[ ! -f "$ARQUIVO_CONFIG.bak" ] && cp "$ARQUIVO_CONFIG" "$ARQUIVO_CONFIG.bak" && echo "Backup do Config criado."
[ ! -f "$ARQUIVO_CUSTOM.bak" ] && cp "$ARQUIVO_CUSTOM" "$ARQUIVO_CUSTOM.bak" && echo "Backup do Custom criado."

# 3. Alterações no libretroConfig.py (SaveState e Driver)
echo "[3/6] Modificando SaveState e Input Driver..."
# SaveState: false -> true
sed -i "s/retroarchConfig\['savestate_auto_load'\] = 'false'/retroarchConfig['savestate_auto_load'] = 'true'/g" "$ARQUIVO_CONFIG"
# Input Driver: udev -> "x"
sed -i "s/retroarchConfig\['input_joypad_driver'\] = 'udev'/retroarchConfig['input_joypad_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_driver'\] = 'udev'/retroarchConfig['input_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"

# 4. Alteração no libretroRetroarchCustom.py (Hotkey)
echo "[4/6] Modificando Hotkey (shift -> null)..."
# Procura a linha 'input_enable_hotkey' e troca "shift" por "null"
sed -i "/'input_enable_hotkey'/ s/\"shift\"/\"null\"/" "$ARQUIVO_CUSTOM"

# 5. Alteração no libretroRetroarchCustom.py (NOTIFICAÇÕES)
echo "[5/6] Desabilitando Notificações (OSD)..."
# Procura a linha 'video_font_enable' e troca "true" por "false"
sed -i "/'video_font_enable'/ s/\"true\"/\"false\"/" "$ARQUIVO_CUSTOM"

# 6. Verificação
echo "--- Verificando mudanças ---"
echo "> SaveState (deve ser 'true'):"
grep "savestate_auto_load" "$ARQUIVO_CONFIG" | grep "true"

echo "> Drivers (deve ser \"x\"):"
grep "input_.*driver" "$ARQUIVO_CONFIG"

echo "> Hotkey (deve ser \"null\"):"
grep "input_enable_hotkey" "$ARQUIVO_CUSTOM"

echo "> Notificações (deve ser \"false\"):"
grep "video_font_enable" "$ARQUIVO_CUSTOM"

echo "--- Concluído! ---"

echo "--- Concluído! Reinicie ou inicie um jogo para testar. ---"

```
