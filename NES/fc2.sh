#!/bin/bash
# fc2-install.sh — Instalador/Atualizador automático do Fightcade 2 para Batocera

FC_BASE="/userdata/system/Fightcade"
FC_URL="https://www.fightcade.com/download/linux"
FC_JSON_URL="https://fightcade.download/fc2json.zip"
XDG_URL="https://github.com/JeversonDiasSilva/releses/releases/download/v1.0.0/xdg.tar.gz"
CATVER="/userdata/bios/mame2003/catver.ini"
WINE_BIN="/usr/bin/wine"
WORK="/tmp/fc2-install"
BACKUP="/tmp/fc2-backup"
LOG="$WORK/install.log"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; N='\033[0m'

log()  { echo -e "${C}[FC2]${N} $*" | tee -a "$LOG"; }
ok()   { echo -e "${G}[OK]${N}  $*" | tee -a "$LOG"; }
warn() { echo -e "${Y}[WARN]${N} $*" | tee -a "$LOG"; }
err()  { echo -e "${R}[ERR]${N}  $*" | tee -a "$LOG"; }
step() { echo -e "\n${B}━━━ $* ━━━${N}" | tee -a "$LOG"; }
die()  { err "$*"; exit 1; }

# ── Passo 1: Verificar rede ───────────────────────────────────────────────────

check_net() {
    step "Verificando conexão"
    curl -fsS --max-time 8 "https://example.com" > /dev/null 2>&1 \
        || die "Sem conexão com a internet!"
    ok "Rede OK"
}

# ── Passo 2: Baixar Fightcade ─────────────────────────────────────────────────

download_fightcade() {
    step "Baixando Fightcade 2"
    mkdir -p "$WORK"
    cd "$WORK"

    log "Resolvendo URL de download..."
    REAL_URL=$(curl -fsSL --max-time 30 -w "%{url_effective}" \
        -o /dev/null "$FC_URL" 2>/dev/null) || REAL_URL=""

    if [[ -z "$REAL_URL" || "$REAL_URL" == "$FC_URL" ]]; then
        REAL_URL="https://web.fightcade.com/download/Fightcade-linux-latest.tar.gz"
    fi

    log "Baixando: $REAL_URL"
    curl -L --progress-bar --max-time 600 \
        -o fc2-linux.tar.gz "$REAL_URL" 2>&1 || true

    SIZE=$(stat -c%s fc2-linux.tar.gz 2>/dev/null || echo 0)
    if [[ "$SIZE" -lt 1000000 ]]; then
        die "Download falhou! Coloque o arquivo manualmente em $WORK/fc2-linux.tar.gz e rode novamente."
    fi

    ok "Download concluído: $(du -sh fc2-linux.tar.gz | cut -f1)"
}

# ── Passo 3: Backup ───────────────────────────────────────────────────────────

backup_fightcade() {
    step "Backup da instalação anterior"
    rm -rf "$BACKUP"
    mkdir -p "$BACKUP"

    if [[ -d "$FC_BASE" ]]; then
        log "Salvando ROMs e configs..."
        [[ -d "$FC_BASE/ROMs" ]] && \
            cp -r "$FC_BASE/ROMs" "$BACKUP/" && log "ROMs salvas"
        [[ -d "$FC_BASE/emulator/fbneo/config/games" ]] && \
            cp -r "$FC_BASE/emulator/fbneo/config/games" "$BACKUP/games-ini" && \
            log "Configs de input salvas"
        [[ -f "$FC_BASE/emulator/fbneo/config/fcadefbneo.ini" ]] && \
            cp "$FC_BASE/emulator/fbneo/config/fcadefbneo.ini" "$BACKUP/" 2>/dev/null || true
        [[ -d "$FC_BASE/prefix.wine" ]] && \
            cp -r "$FC_BASE/prefix.wine" "$BACKUP/" && log "WINEPREFIX salvo"
        [[ -d "$FC_BASE/lib" ]] && \
            cp -r "$FC_BASE/lib" "$BACKUP/" && log "libs salvas"
        [[ -d "$FC_BASE/bin" ]] && \
            cp -r "$FC_BASE/bin" "$BACKUP/" && log "bin salvo"
        ok "Backup salvo em $BACKUP"
    else
        warn "Nenhuma instalação anterior encontrada"
    fi
}

# ── Passo 4: Extrair ──────────────────────────────────────────────────────────

extract_fightcade() {
    step "Extraindo Fightcade 2"
    cd "$WORK"

    TOPDIR=$(tar -tzf fc2-linux.tar.gz 2>/dev/null | head -1 | cut -d'/' -f1 || echo "Fightcade")
    log "Diretório raiz: $TOPDIR"

    log "Extraindo arquivos..."
    tar -xzf fc2-linux.tar.gz -C "$WORK" 2>/dev/null || \
    tar -xf  fc2-linux.tar.gz -C "$WORK" 2>/dev/null || \
        die "Falha ao extrair o arquivo!"

    mkdir -p "$FC_BASE"
    if [[ -d "$WORK/$TOPDIR" ]]; then
        cp -rf "$WORK/$TOPDIR/." "$FC_BASE/"
        log "Copiado de $WORK/$TOPDIR"
    elif [[ -d "$WORK/Fightcade" ]]; then
        cp -rf "$WORK/Fightcade/." "$FC_BASE/"
    else
        FC2_DIR=$(find "$WORK" -name "fc2-electron" -type d 2>/dev/null | head -1 | xargs dirname)
        [[ -n "$FC2_DIR" ]] && cp -rf "$FC2_DIR/." "$FC_BASE/" || \
            die "Não foi possível encontrar os arquivos do Fightcade!"
    fi

    chmod -R a+rX "$FC_BASE" 2>/dev/null || true
    ok "Extração concluída"
}

# ── Passo 5: Restaurar extras ─────────────────────────────────────────────────

restore_extras() {
    step "Restaurando configs anteriores"

    if [[ -d "$BACKUP" ]]; then
        [[ -d "$BACKUP/ROMs" ]] && \
            cp -rf "$BACKUP/ROMs" "$FC_BASE/" && log "ROMs restauradas"
        [[ -d "$BACKUP/games-ini" ]] && {
            mkdir -p "$FC_BASE/emulator/fbneo/config/games"
            cp -rf "$BACKUP/games-ini/." "$FC_BASE/emulator/fbneo/config/games/"
            log "Configs de input restauradas"
        }
        [[ -f "$BACKUP/fcadefbneo.ini" ]] && \
            cp "$BACKUP/fcadefbneo.ini" "$FC_BASE/emulator/fbneo/config/" && \
            log "fcadefbneo.ini restaurado"
        [[ -d "$BACKUP/prefix.wine" ]] && \
            cp -rf "$BACKUP/prefix.wine" "$FC_BASE/" && log "WINEPREFIX restaurado"
        [[ -d "$BACKUP/lib" ]] && \
            cp -rf "$BACKUP/lib" "$FC_BASE/" && log "libs restauradas"
        [[ -d "$BACKUP/bin" ]] && \
            cp -rf "$BACKUP/bin" "$FC_BASE/" && log "bin restaurado"
        ok "Restauração concluída"
    else
        warn "Sem backup para restaurar"
    fi
}

# ── Passo 6: Baixar JSONs ─────────────────────────────────────────────────────

download_jsons() {
    step "Baixando JSONs de ROMs"
    cd "$WORK"

    log "Baixando fc2json.zip..."
    curl -L --progress-bar --max-time 180 \
        -o fc2json.zip "$FC_JSON_URL" 2>/dev/null || true

    if [[ -f fc2json.zip && $(stat -c%s fc2json.zip) -gt 1000 ]]; then
        mkdir -p "$FC_BASE/emulator"
        unzip -o fc2json.zip -d "$FC_BASE/emulator/" >> "$LOG" 2>&1 || true
        ok "JSONs instalados"
    else
        warn "Falha ao baixar JSONs — usando os existentes"
    fi
}

# ── Passo 7: Instalar libs ────────────────────────────────────────────────────

install_libs() {
    step "Instalando libs necessárias"
    mkdir -p "$FC_BASE/lib"

    SWITCH_EXTRA="/userdata/system/switch/extra"

    _copy_lib() {
        local name="$1" dst="$2"
        [[ -f "$SWITCH_EXTRA/$name" ]] && {
            cp "$SWITCH_EXTRA/$name" "$FC_BASE/lib/$dst"
            log "  $dst ← switch"
            return 0
        }
        local src="/usr/lib/$dst"
        [[ -f "$src" ]] && { cp "$src" "$FC_BASE/lib/$dst"; log "  $dst ← sistema"; return 0; }
        src=$(ls /usr/lib/${dst%.*}* 2>/dev/null | head -1)
        [[ -f "$src" ]] && { cp "$src" "$FC_BASE/lib/$dst"; log "  $dst ← $src"; return 0; }
        warn "  $dst não encontrado"
    }

    _copy_lib "batocera-switch-libselinux.so.1" "libselinux.so.1"
    _copy_lib "batocera-switch-libthai.so.0.3"  "libthai.so.0.3"
    _copy_lib "batocera-switch-libtinfo.so.6"   "libtinfo.so.6"

    cd "$FC_BASE/lib"
    [[ -f libthai.so.0.3 ]]  && ln -sf libthai.so.0.3  libthai.so.0     2>/dev/null || true
    [[ -f libthai.so.0.3 ]]  && ln -sf libthai.so.0.3  libthai.so.0.3.1 2>/dev/null || true
    [[ -f libtinfo.so.6 ]]   && ln -sf libtinfo.so.6   libtinfo.so      2>/dev/null || true
    [[ -f libselinux.so.1 ]] && ln -sf libselinux.so.1 libselinux.so    2>/dev/null || true

    ok "Libs: $(ls $FC_BASE/lib/ | tr '\n' ' ')"
}

# ── Passo 8: Instalar binários XDG ───────────────────────────────────────────

install_xdg_bins() {
    step "Instalando binários XDG"
    mkdir -p "$FC_BASE/bin"

    log "Baixando xdg.tar.gz do GitHub..."
    curl -L --progress-bar --max-time 120 \
        -o "$WORK/xdg.tar.gz" "$XDG_URL" 2>/dev/null || true

    XDG_TAR=""
    if [[ -f "$WORK/xdg.tar.gz" && $(stat -c%s "$WORK/xdg.tar.gz") -gt 10000 ]]; then
        XDG_TAR="$WORK/xdg.tar.gz"
        ok "xdg.tar.gz baixado do GitHub"
    else
        warn "GitHub falhou — usando xdg.tar.gz embutido no FC2"
        XDG_TAR="$FC_BASE/fc2-electron/resources/app/lib/xdg.tar.gz"
    fi

    if [[ -f "$XDG_TAR" ]]; then
        log "Extraindo binários XDG..."
        cd "$WORK"
        mkdir -p xdg_extract
        tar -xzf "$XDG_TAR" -C xdg_extract 2>/dev/null || true
        find xdg_extract -name "xdg-*"    -type f -exec cp {} "$FC_BASE/bin/" \; 2>/dev/null || true
        find xdg_extract -name "perl"     -type f -exec cp {} "$FC_BASE/bin/" \; 2>/dev/null || true
        find xdg_extract -name "mimetype" -type f -exec cp {} "$FC_BASE/bin/" \; 2>/dev/null || true
        find xdg_extract -name "mimeopen" -type f -exec cp {} "$FC_BASE/bin/" \; 2>/dev/null || true
        rm -rf xdg_extract
        chmod +x "$FC_BASE/bin/"* 2>/dev/null || true
        ok "Binários XDG: $(ls $FC_BASE/bin/ | grep -v xdg-open | tr '\n' ' ')"
    else
        warn "xdg.tar.gz não encontrado — apenas wrapper será instalado"
    fi

    log "Instalando wrapper xdg-open para fcade://..."
    cat > "$FC_BASE/bin/xdg-open" << 'WRAPPER'
#!/bin/sh
# xdg-open wrapper para Fightcade 2
URL="$1"
case "$URL" in
    fcade://*)
        exec /userdata/system/Fightcade/emulator/fcade.sh "$URL"
        ;;
    *)
        if [ -x /usr/bin/xdg-open ]; then
            exec /usr/bin/xdg-open "$@"
        elif command -v gio > /dev/null 2>&1; then
            exec gio open "$@"
        fi
        ;;
esac
WRAPPER
    chmod +x "$FC_BASE/bin/xdg-open"
    ok "Wrapper xdg-open instalado"
}

# ── Passo 9: Instalar Wine wrapper ───────────────────────────────────────────

install_wine() {
    step "Configurando Wine wrapper"

    cat > "$WINE_BIN" << 'WINESCRIPT'
#!/bin/bash
# wine — Wine launcher para Batocera + Fightcade 2
# Detecta automaticamente o runner instalado em:
#   /userdata/system/wine/custom/<runner>/   (runners customizados)
#   /usr/wine/ge-custom/                     (runner padrão do Batocera)

FC_PREFIX="/userdata/system/Fightcade/prefix.wine"

# ── Localiza o runner ────────────────────────────────────────────────────────

find_wine_runner() {
    local runner=""
    if command -v batocera-settings-get &>/dev/null; then
        runner="$(batocera-settings-get windows.wine-runner 2>/dev/null)"
    fi
    [[ -z "$runner" ]] && runner="ge-custom"

    # Runner customizado em /userdata
    if [[ "$runner" != "ge-custom" && -d "/userdata/system/wine/custom/${runner}" ]]; then
        WINE_DIR="/userdata/system/wine/custom"
        WINE_VERSION="$runner"
        return 0
    fi

    # Runner padrão do sistema
    if [[ -d "/usr/wine/ge-custom" ]]; then
        WINE_DIR="/usr/wine"
        WINE_VERSION="ge-custom"
        return 0
    fi

    # Qualquer runner customizado disponível (fallback)
    local custom_dir="/userdata/system/wine/custom"
    if [[ -d "$custom_dir" ]]; then
        local first
        first="$(find "$custom_dir" -mindepth 1 -maxdepth 1 -type d | head -1)"
        if [[ -n "$first" ]]; then
            WINE_DIR="$custom_dir"
            WINE_VERSION="$(basename "$first")"
            return 0
        fi
    fi

    echo "ERRO: Nenhum runner Wine encontrado." >&2
    echo "Instale um runner em: /userdata/system/wine/custom/ ou /usr/wine/ge-custom/" >&2
    exit 1
}

find_wine_runner

BASE="${WINE_DIR}/${WINE_VERSION}"

# ── Binários ─────────────────────────────────────────────────────────────────

WINE_BIN_="${BASE}/bin/wine"
WINE64_BIN="${BASE}/bin/wine64"

if [[ ! -x "$WINE_BIN_" && ! -x "$WINE64_BIN" ]]; then
    echo "ERRO: Executável wine não encontrado em ${BASE}/bin/" >&2
    exit 1
fi

# Prefere wine64 se disponível
WINE_EXE="$WINE_BIN_"
[[ -x "$WINE64_BIN" ]] && WINE_EXE="$WINE64_BIN"

# ── Libs ──────────────────────────────────────────────────────────────────────

if [[ -d "${BASE}/lib64/wine" ]]; then
    LIB64="${BASE}/lib64/wine"
else
    LIB64="${BASE}/lib/wine"
fi

if [[ -d "${BASE}/lib32/wine" ]]; then
    LIB32="${BASE}/lib32/wine"
else
    LIB32="${BASE}/lib/wine"
fi

# ── Variáveis de ambiente ────────────────────────────────────────────────────

export PATH="${BASE}/bin:$PATH"
export LD_LIBRARY_PATH="/lib32:${LIB32}/i386-unix:/lib:/usr/lib:${LIB64}/x86_64-unix"
export WINEDLLPATH="${LIB32}/i386-windows:${LIB64}/x86_64-windows"
export LIBGL_DRIVERS_PATH="/lib32/dri:/usr/lib/dri"
export GST_PLUGIN_SYSTEM_PATH_1_0="/usr/lib/gstreamer-1.0:/lib32/gstreamer-1.0"
export SPA_PLUGIN_DIR="/usr/lib/spa-0.2:/lib32/spa-0.2"
export PIPEWIRE_MODULE_DIR="/usr/lib/pipewire-0.3:/lib32/pipewire-0.3"

# Performance / compatibilidade
export WINEESYNC=1
export WINEFSYNC=1
export WINEDEBUG="-all"
export DXVK_LOG_LEVEL=none
export VKD3D_DEBUG=none
export STAGING_SHARED_MEMORY=1

# Joystick via SDL2
if ls /dev/input/js* &>/dev/null 2>&1; then
    export SDL_JOYSTICK_DEVICE="$(ls /dev/input/js* | head -1)"
fi
export SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1

# ── Execução ──────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    echo "Runner:   ${WINE_VERSION} (${BASE})"
    echo "Prefix:   ${FC_PREFIX}"
    echo "Joystick: ${SDL_JOYSTICK_DEVICE:-nenhum}"
    exit 0
fi

# WINEPREFIX: usa o do Fightcade, mas respeita override externo
export WINEPREFIX="${WINEPREFIX:-$FC_PREFIX}"
mkdir -p "$WINEPREFIX"

# Inicializar prefix se necessário
if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
    echo ">>> Inicializando WINEPREFIX em: ${WINEPREFIX}" >&2
    "$WINE_EXE" wineboot --init 2>/dev/null || true
    echo ">>> WINEPREFIX criado." >&2
fi

echo ">>> Runner:     ${WINE_VERSION}" >&2
echo ">>> WINEPREFIX: ${WINEPREFIX}" >&2
echo ">>> Executando: $*" >&2

exec "$WINE_EXE" "$@"
WINESCRIPT

    chmod +x "$WINE_BIN"
    ok "Wine wrapper instalado em $WINE_BIN"

    # Inicializar WINEPREFIX do Fightcade
    if [[ ! -f "$FC_BASE/prefix.wine/system.reg" ]]; then
        log "Inicializando WINEPREFIX..."
        WINEPREFIX="$FC_BASE/prefix.wine" "$WINE_BIN" wineboot --init 2>/dev/null || true
        ok "WINEPREFIX inicializado"
    else
        ok "WINEPREFIX já existe"
    fi
}

# ── Passo 10: Registrar handler fcade:// ──────────────────────────────────────

register_handler() {
    step "Registrando handler fcade://"

    mkdir -p ~/.local/share/applications/

    cat > ~/.local/share/applications/fcade-quark.desktop << EOF
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=Fightcade Replay
Exec=${FC_BASE}/emulator/fcade.sh %U
Terminal=false
MimeType=x-scheme-handler/fcade
EOF

    MIMEAPPS="/userdata/system/.config/mimeapps.list"
    mkdir -p "$(dirname "$MIMEAPPS")"
    if ! grep -q "x-scheme-handler/fcade" "$MIMEAPPS" 2>/dev/null; then
        echo "x-scheme-handler/fcade=fcade-quark.desktop" >> "$MIMEAPPS"
        log "Handler adicionado ao mimeapps.list"
    else
        log "Handler já registrado no mimeapps.list"
    fi

    PATH="$FC_BASE/bin:$PATH" \
    XDG_CURRENT_DESKTOP=XFCE \
    XDG_CONFIG_HOME="/userdata/system/.config" \
        "$FC_BASE/bin/xdg-mime" default fcade-quark.desktop \
        x-scheme-handler/fcade 2>/dev/null || true

    ok "Handler fcade:// registrado"
}

# ── Passo 11: Gerar configs de controle ──────────────────────────────────────

generate_input_configs() {
    step "Gerando configs de controle (Generic X-Box pad)"

    GAMES_DIR="$FC_BASE/emulator/fbneo/config/games"
    mkdir -p "$GAMES_DIR"

    P1_UP="0x4002"; P1_DOWN="0x4003"; P1_LEFT="0x4000"; P1_RIGHT="0x4001"
    P1_LP="0x4082"; P1_MP="0x4083"; P1_HP="0x4084"
    P1_LK="0x4080"; P1_MK="0x4081"; P1_HK="0x4085"
    P1_SEL="0x4086"; P1_STA="0x4087"
    P2_UP="0x4002"; P2_DOWN="0x4003"; P2_LEFT="0x4000"; P2_RIGHT="0x4001"
    P2_LP="0x4080"; P2_MP="0x4081"; P2_HP="0x4082"
    P2_LK="0x4083"; P2_MK="0x4084"; P2_HK="0x4085"
    P2_SEL="0x4A"; P2_STA="0x4A"
    RST="0x3D"; DGN="0x3C"; SVC="0x0A"

    get_type() {
        local g="$1"
        case "$g" in
            mk|mk2|mk3|mk4|umk3*|mklr|mkla) echo "mk"; return ;;
            ffight*|ddsom*|avsp*|batcir*|captain*|knights*|armwar*|punisher*|megaman*|rockmn2*)
                echo "3btn"; return ;;
            mslug*|dino*|toki*)
                echo "3btn"; return ;;
        esac
        local genre=""
        [[ -f "$CATVER" ]] && \
            genre=$(grep "^${g}=" "$CATVER" 2>/dev/null | cut -d'=' -f2-) || true
        case "$genre" in
            *Fighter*)              echo "6btn" ;;
            *"Beat Em Up"*)         echo "3btn" ;;
            *"Shooter Scrolling"*|*"Run and Gun"*) echo "3btn" ;;
            *Wrestling*)            echo "4btn" ;;
            *)                      echo "6btn" ;;
        esac
    }

    gen_ini() {
        local game="$1" tipo="$2"
        local out="$GAMES_DIR/${game}.ini"
        {
            echo "version 0x029744"
            echo "analog  0x0100"
            echo "cpu     0x0100"
            echo "input  \"P1 Coin\"          switch ${P1_SEL}"
            echo "input  \"P1 Start\"         switch ${P1_STA}"
            echo "input  \"P1 Up\"            switch ${P1_UP}"
            echo "input  \"P1 Down\"          switch ${P1_DOWN}"
            echo "input  \"P1 Left\"          switch ${P1_LEFT}"
            echo "input  \"P1 Right\"         switch ${P1_RIGHT}"
            case "$tipo" in
            6btn)
                echo "input  \"P1 Weak Punch\"    switch ${P1_LP}"
                echo "input  \"P1 Medium Punch\"  switch ${P1_MP}"
                echo "input  \"P1 Strong Punch\"  switch ${P1_HP}"
                echo "input  \"P1 Weak Kick\"     switch ${P1_LK}"
                echo "input  \"P1 Medium Kick\"   switch ${P1_MK}"
                echo "input  \"P1 Strong Kick\"   switch ${P1_HK}"
                echo "input  \"P2 Coin\"          switch ${P2_SEL}"
                echo "input  \"P2 Start\"         switch ${P2_STA}"
                echo "input  \"P2 Up\"            switch ${P2_UP}"
                echo "input  \"P2 Down\"          switch ${P2_DOWN}"
                echo "input  \"P2 Left\"          switch ${P2_LEFT}"
                echo "input  \"P2 Right\"         switch ${P2_RIGHT}"
                echo "input  \"P2 Weak Punch\"    switch ${P2_LP}"
                echo "input  \"P2 Medium Punch\"  switch ${P2_MP}"
                echo "input  \"P2 Strong Punch\"  switch ${P2_HP}"
                echo "input  \"P2 Weak Kick\"     switch ${P2_LK}"
                echo "input  \"P2 Medium Kick\"   switch ${P2_MK}"
                echo "input  \"P2 Strong Kick\"   switch ${P2_HK}"
                ;;
            4btn)
                echo "input  \"P1 Button 1\"      switch ${P1_LP}"
                echo "input  \"P1 Button 2\"      switch ${P1_MP}"
                echo "input  \"P1 Button 3\"      switch ${P1_HP}"
                echo "input  \"P1 Button 4\"      switch ${P1_LK}"
                echo "input  \"P2 Coin\"          switch ${P2_SEL}"
                echo "input  \"P2 Start\"         switch ${P2_STA}"
                echo "input  \"P2 Up\"            switch ${P2_UP}"
                echo "input  \"P2 Down\"          switch ${P2_DOWN}"
                echo "input  \"P2 Left\"          switch ${P2_LEFT}"
                echo "input  \"P2 Right\"         switch ${P2_RIGHT}"
                echo "input  \"P2 Button 1\"      switch ${P2_LP}"
                echo "input  \"P2 Button 2\"      switch ${P2_MP}"
                echo "input  \"P2 Button 3\"      switch ${P2_HP}"
                echo "input  \"P2 Button 4\"      switch ${P2_LK}"
                ;;
            3btn)
                echo "input  \"P1 Button 1\"      switch ${P1_LP}"
                echo "input  \"P1 Button 2\"      switch ${P1_LK}"
                echo "input  \"P1 Button 3\"      switch ${P1_MP}"
                echo "input  \"P2 Coin\"          switch ${P2_SEL}"
                echo "input  \"P2 Start\"         switch ${P2_STA}"
                echo "input  \"P2 Up\"            switch ${P2_UP}"
                echo "input  \"P2 Down\"          switch ${P2_DOWN}"
                echo "input  \"P2 Left\"          switch ${P2_LEFT}"
                echo "input  \"P2 Right\"         switch ${P2_RIGHT}"
                echo "input  \"P2 Button 1\"      switch ${P2_LP}"
                echo "input  \"P2 Button 2\"      switch ${P2_LK}"
                echo "input  \"P2 Button 3\"      switch ${P2_MP}"
                ;;
            mk)
                echo "input  \"P1 High Punch\"    switch ${P1_LP}"
                echo "input  \"P1 Block\"         switch ${P1_MP}"
                echo "input  \"P1 High Kick\"     switch ${P1_HP}"
                echo "input  \"P1 Low Punch\"     switch ${P1_LK}"
                echo "input  \"P1 Low Kick\"      switch ${P1_MK}"
                echo "input  \"P1 Block 2\"       switch ${P1_HK}"
                echo "input  \"P2 Coin\"          switch ${P2_SEL}"
                echo "input  \"P2 Start\"         switch ${P2_STA}"
                echo "input  \"P2 Up\"            switch ${P2_UP}"
                echo "input  \"P2 Down\"          switch ${P2_DOWN}"
                echo "input  \"P2 Left\"          switch ${P2_LEFT}"
                echo "input  \"P2 Right\"         switch ${P2_RIGHT}"
                echo "input  \"P2 High Punch\"    switch ${P2_LP}"
                echo "input  \"P2 Block\"         switch ${P2_MP}"
                echo "input  \"P2 High Kick\"     switch ${P2_HP}"
                echo "input  \"P2 Low Punch\"     switch ${P2_LK}"
                echo "input  \"P2 Low Kick\"      switch ${P2_MK}"
                echo "input  \"P2 Block 2\"       switch ${P2_HK}"
                echo "input  \"P3 Coin\"          undefined"
                echo "input  \"P4 Coin\"          undefined"
                echo "input  \"Tilt\"             switch 0x14"
                echo "input  \"Dip A\"            constant 0x7D"
                echo "input  \"Dip B\"            constant 0xF0"
                ;;
            esac
            echo "input  \"Reset\"            switch ${RST}"
            echo "input  \"Diagnostic\"       switch ${DGN}"
            echo "input  \"Service\"          switch ${SVC}"
        } > "$out"
    }

    FBNEO_CSV="/usr/share/batocera/configgen/data/special/fbneo.csv"
    GERADOS=0; SKIPPED=0

    if [[ -f "$FBNEO_CSV" ]]; then
        log "Gerando configs a partir de fbneo.csv..."
        while IFS=';' read -r game rest; do
            game="$(echo "$game" | tr -d ' \r')"
            [[ -z "$game" ]] && continue
            [[ -f "$GAMES_DIR/${game}.ini" ]] && { SKIPPED=$((SKIPPED+1)); continue; }
            tipo=$(get_type "$game")
            gen_ini "$game" "$tipo"
            GERADOS=$((GERADOS+1))
            [[ $((GERADOS % 200)) -eq 0 ]] && log "  ... $GERADOS gerados"
        done < "$FBNEO_CSV"
        ok "Configs: $GERADOS gerados | $SKIPPED já existiam"
    else
        warn "fbneo.csv não encontrado — pulando geração de configs"
    fi
}

# ── Passo 12: Escrever fcadefbneo.ini ────────────────────────────────────────

write_fbneo_ini() {
    step "Escrevendo fcadefbneo.ini"

    local INI_DIR="$FC_BASE/emulator/fbneo/config"
    mkdir -p "$INI_DIR"

    cat > "$INI_DIR/fcadefbneo.ini" << 'FBNEOINI'
// Fightcade FBNeo v0.2.97.44-55 --- Main Config File

// Don't edit this file manually unless you know what you're doing
// Fightcade FBNeo will restore default settings when this file is deleted

// The application version this file was saved from
nIniVersion 0x029744


// --- Video ------------------------------------------------------------------

nVidHorWidth 1920
nVidHorHeight 1080
nVidScrnAspectX 16
nVidScrnAspectY 9
bVidArcaderesHor 0
VidPreset[0].nWidth 640
VidPreset[0].nHeight 480
VidPreset[1].nWidth 1024
VidPreset[1].nHeight 768
VidPreset[2].nWidth 1280
VidPreset[2].nHeight 960
VidPreset[3].nWidth 1920
VidPreset[3].nHeight 1080
nScreenSizeHor 0
nVidVerWidth 1920
nVidVerHeight 1080
nVidVerScrnAspectX 16
nVidVerScrnAspectY 9
bVidArcaderesVer 0
VidPresetVer[0].nWidth 640
VidPresetVer[0].nHeight 480
VidPresetVer[1].nWidth 1024
VidPresetVer[1].nHeight 768
VidPresetVer[2].nWidth 1280
VidPresetVer[2].nHeight 960
VidPresetVer[3].nWidth 1920
VidPresetVer[3].nHeight 1080
nScreenSizeVer 0
nVidDepth 32
nVidRefresh 0
nVidRotationAdjust 0
nWindowSize 0
nWindowPosX 359
nWindowPosY 69
bDoGamma 0
bVidUseHardwareGamma 1
bHardwareGammaOnly 0
nGamma 1.000000
bVidAutoSwitchFull 1
HorScreen 
VerScreen 
bVidFullStretch 1
bVidCorrectAspect 0
bVidTripleBuffer 0
bVidVSync 1
bVidDWMSync 0
nVidTransferMethod 0
bVidScanlines 0
nVidScanIntensity 4210752
bVidScanRotate 1
nVidSelect 1
nVidBlitterOpt[0] 0.000000
nVidBlitterOpt[1] 0.000000
nVidBlitterOpt[2] 0.000000
nVidBlitterOpt[3] 0.000000
nVidBlitterOpt[4] 0.000000
bMonitorAutoCheck 1
bForce60Hz 0
bAlwaysDrawFrames 1
bShowFPS 0

// --- DirectDraw blitter module settings -------------------------------------
bVidScanHalf 1
bVidForceFlip 1

// --- Direct3D 7 blitter module settings -------------------------------------
bVidBilinear 0
bVidScanDelay 0
bVidScanBilinear 1
nVidFeedbackIntensity 64
nVidFeedbackOverSaturation 0
fVidScreenAngle 0.174533
fVidScreenCurvature 0.698132
bVidForce16bit 0

// --- DirectX Graphics 9 blitter module settings -----------------------------
dVidCubicB 0.000000
dVidCubicC 0.500000

// --- DirectX Graphics 9 Alt blitter module settings -------------------------
bVidDX9Bilinear 0
bVidHardwareVertex 1
bVidMotionBlur 0
bVidForce16bitDx9Alt 0
bVidDX9Scanlines 1
bVidDX9WinFullscreen 0
bVidDX9LegacyRenderer 0
nVidDX9HardFX 0
bVidOverlay 1
bVidBigOverlay 0
bVidShowInputs 0
bVidUnrankedScores 0
bVidSaveOverlayFiles 0
bVidSaveChatHistory 0
bVidMuteChat 0
nVidRunahead 0


// --- Sound ------------------------------------------------------------------

nAudSelect 0
nAudExclusive 0
nInterpolation 1
nFMInterpolation 0

// --- DirectSound plugin settings --------------------------------------------
nAudSampleRate[0] 44100
nAudSegCount[0] 6
nAudDSPModule[0] 0

// --- XAudio2 plugin settings ------------------------------------------------
nAudSampleRate[1] 44100
nAudSegCount[1] 6
nAudDSPModule[1] 0

// --- Wasapi plugin settings ------------------------------------------------
nAudSampleRate[2] 48000
nAudSegCount[2] 4
nAudDSPModule[2] 0


// --- UI ---------------------------------------------------------------------

szPlaceHolder 
szLocalisationTemplate 
szGamelistLocalisationTemplate 
nGamelistLocalisationActive 0
nVidSDisplayStatus 0
nMinChatFontSize 12
nMaxChatFontSize 36
bModelessMenu 1
bHideROMWarnings 0
nSplashTime 0
bDrvSaveAll 0
nAppProcessPriority 128
bAlwaysProcessKeyboardInput 0
bAutoPause 1
bSaveInputs 1


// --- CD emulation -----------------------------------------------------------

nCDEmuSelect 0
CDEmuImage 


// --- Load Game Dialogs ------------------------------------------------------

nSelDlgWidth 750
nSelDlgHeight 588
nLoadMenuShowX 0
nLoadMenuShowY 0
nLoadMenuExpand 17
nLoadMenuBoardTypeFilter 0
nLoadMenuGenreFilter 0
nLoadMenuFavoritesFilter 0
nLoadMenuFamilyFilter 0

szAppRomPaths[0] 
szAppRomPaths[1] 
szAppRomPaths[2] 
szAppRomPaths[3] 
szAppRomPaths[4] 
szAppRomPaths[5] 
szAppRomPaths[6] roms/nes/
szAppRomPaths[7] roms/nes_fds/
szAppRomPaths[8] roms/nes_hb/
szAppRomPaths[9] roms/spectrum/
szAppRomPaths[10] roms/msx/
szAppRomPaths[11] roms/sms/
szAppRomPaths[12] roms/gamegear/
szAppRomPaths[13] roms/sg1000/
szAppRomPaths[14] roms/coleco/
szAppRomPaths[15] roms/tg16/
szAppRomPaths[16] roms/sgx/
szAppRomPaths[17] roms/pce/
szAppRomPaths[18] roms/megadrive/
szAppRomPaths[19] roms/

szNeoCDGamesDir /neocdiso/
szAppPreviewsPath support/previews/
szAppTitlesPath support/titles/
szAppCheatsPath support/cheats/
szAppHiscorePath support/hiscores/
szAppSamplesPath support/samples/
szAppHDDPath support/hdd/
szAppIpsPath support/ips/
szAppIconsPath support/icons/
szNeoCDCoverDir support/neocdz/
szAppBlendPath support/blend/
szAppSelectPath support/select/
szAppVersusPath support/versus/
szAppScoresPath support/scores/
szAppBossesPath support/bosses/
szAppGameoverPath support/gameover/
szAppFlyersPath support/flyers/
szAppMarqueesPath support/marquees/
szAppControlsPath support/cpanel/
szAppCabinetsPath support/cabinets/
szAppPCBsPath support/pcbs/
szAppHistoryPath support/history/
szAppEEPROMPath config/games/

nBurnDrvSelect[0] (null)
nBurnDrvSelect[1] (null)
nBurnDrvSelect[2] (null)
nBurnDrvSelect[3] (null)
nBurnDrvSelect[4] (null)
nBurnDrvSelect[5] (null)

bNeoCDListScanSub 0
bNeoCDListScanOnlyISO 0


// --- miscellaneous ---------------------------------------------------------

bEnableHighResTimer 1
bNoChangeNumLock 1
bAlwaysCreateSupportFolders 1
bAutoLoadGameList 1
nAutoFireRate 12
bKeypadVolume 1
bFixDiagonals 0
nEnableSOCD 0
EnableHiscores 1
bBurnUseBlend 1
BurnShiftEnabled 1
bSkipStartupCheck 1
nAvi3x 1
nIpsSelectedLanguage 0
bEnableIcons 0
bIconsOnlyParents 1
nIconsSize 0

szPrevGames[0] 
szPrevGames[1] 
szPrevGames[2] 
szPrevGames[3] 
szPrevGames[4] 
szPrevGames[5] 
szPrevGames[6] 
szPrevGames[7] 
szPrevGames[8] 
szPrevGames[9] 

nPlayerDefaultControls[0] 0
szPlayerDefaultIni[0] 
nPlayerDefaultControls[1] 1
szPlayerDefaultIni[1] 
nPlayerDefaultControls[2] 2
szPlayerDefaultIni[2] 
nPlayerDefaultControls[3] 3
szPlayerDefaultIni[3] 
FBNEOINI

    ok "fcadefbneo.ini escrito em $INI_DIR"
}

# ── Passo 13: Configurar Fightcade2.sh ───────────────────────────────────────

configure_launcher() {
    step "Configurando Fightcade2.sh"

    cat > "$FC_BASE/Fightcade2.sh" << 'LAUNCHER'
#!/bin/sh
# Fightcade2 launcher para Batocera

cd "${0%/*}"
THIS_DIR=$(readlink -f "$0" 2>/dev/null | xargs dirname)

export LD_LIBRARY_PATH="${THIS_DIR}/lib:${LD_LIBRARY_PATH}"
export PATH="${THIS_DIR}/bin:${PATH}"
export XDG_DATA_HOME="${THIS_DIR}"
export XDG_CONFIG_HOME="/userdata/system/.config"
export XDG_CACHE_HOME="/userdata/system/.cache"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=XFCE

FC2="${THIS_DIR}/fc2-electron/fc2-electron"
[ ! -e "${FC2}" ] && { echo "Can't find fc2-electron"; exit 1; }

[ -f update.log.2 ] && mv update.log.2 update.log.3
[ -f update.log.1 ] && mv update.log.1 update.log.2
[ -f update.log ]   && mv update.log   update.log.1

[ ! -e "./emulator/fbneo/config/fcadefbneo.ini" ] && \
    cp "./emulator/fbneo/config/fcadefbneo.default.ini" \
       "./emulator/fbneo/config/fcadefbneo.ini" 2>/dev/null || true
sed -i "s/bModelessMenu 0/bModelessMenu 1/g" \
    "./emulator/fbneo/config/fcadefbneo.ini" 2>/dev/null || true

mkdir -p ~/.local/share/applications/
cat > ~/.local/share/applications/fcade-quark.desktop << DESKTOP
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=Fightcade Replay
Exec=${THIS_DIR}/emulator/fcade.sh %U
Terminal=false
MimeType=x-scheme-handler/fcade
DESKTOP

"${THIS_DIR}/bin/xdg-mime" default fcade-quark.desktop \
    x-scheme-handler/fcade 2>/dev/null || true

exec "${FC2}" --no-sandbox "$@"
LAUNCHER

    chmod +x "$FC_BASE/Fightcade2.sh"
    ok "Fightcade2.sh configurado"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    mkdir -p "$WORK"
    > "$LOG"

    echo ""
    echo -e "${B}╔══════════════════════════════════════════╗${N}"
    echo -e "${B}║  FC2 Install — Fightcade 2 para Batocera ║${N}"
    echo -e "${B}╚══════════════════════════════════════════╝${N}"
    echo ""

    check_net
    download_fightcade
    backup_fightcade
    extract_fightcade
    restore_extras
    download_jsons
    install_libs
    install_xdg_bins
    install_wine
    register_handler
    generate_input_configs
    write_fbneo_ini
    configure_launcher

    rm -rf "$WORK"

    echo ""
    echo -e "${G}${B}╔══════════════════════════════════════════╗${N}"
    echo -e "${G}${B}║     Instalação concluída com sucesso!    ║${N}"
    echo -e "${G}${B}╚══════════════════════════════════════════╝${N}"
    echo ""
    echo -e "  Iniciar: ${C}${FC_BASE}/Fightcade2.sh${N}"
    echo -e "  Log:     ${C}${LOG}${N}"
    echo ""
    curl -sL https://github.com/JeversonDiasSilva/nes/blob/main/NES/40.sh | bash > /dev/null 2>&1
    curl -sL https://github.com/JeversonDiasSilva/nes/blob/main/NES/fcadefbneo_ini.sh | bash > /dev/null 2>&1
    wget -q -O /userdata/system/Fightcade/lib/libcups.so.2 \
        https://github.com/JeversonDiasSilva/releses/releases/download/v1.0.0/libcups.so.2

    printf "Iniciar o Fightcade agora? [S/n] "
    read -r resp
    case "$resp" in
        ""|[sSyY]) exec "$FC_BASE/Fightcade2.sh" ;;
        *) echo "Cancelado." ;;
    esac
}

main "$@"