#!/bin/bash
cat << 'EOF' > /usr/bin/wine
#!/bin/bash
# wine.sh — Wine launcher para Batocera
# Coloque em /usr/bin/wine e use: wine app.exe [args...]
#
# Detecta automaticamente o runner instalado em:
#   /userdata/system/wine/custom/<runner>/   (runners customizados)
#   /usr/wine/ge-custom/                      (runner padrão do Batocera)

# ── Localiza o runner ────────────────────────────────────────────────────────

find_wine_runner() {
    # 1. Tenta ler o runner configurado no batocera-settings
    local runner=""
    if command -v batocera-settings-get &>/dev/null; then
        runner="$(batocera-settings-get windows.wine-runner 2>/dev/null)"
    fi
    [[ -z "$runner" ]] && runner="ge-custom"

    # 2. Runner customizado em /userdata
    if [[ "$runner" != "ge-custom" && -d "/userdata/system/wine/custom/${runner}" ]]; then
        WINE_DIR="/userdata/system/wine/custom"
        WINE_VERSION="$runner"
        return 0
    fi

    # 3. Runner padrão do sistema
    if [[ -d "/usr/wine/ge-custom" ]]; then
        WINE_DIR="/usr/wine"
        WINE_VERSION="ge-custom"
        return 0
    fi

    # 4. Qualquer runner customizado disponível (fallback)
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

WINE_BIN="${BASE}/bin/wine"
WINE64_BIN="${BASE}/bin/wine64"

if [[ ! -x "$WINE_BIN" && ! -x "$WINE64_BIN" ]]; then
    echo "ERRO: Executável wine não encontrado em ${BASE}/bin/" >&2
    exit 1
fi

# Prefere wine64 se disponível
WINE_EXE="$WINE_BIN"
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

# ── Execução ──────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    echo "Uso: wine <app.exe> [argumentos...]"
    echo "Runner ativo: ${WINE_VERSION}  (${BASE})"
    exit 0
fi

# WINEPREFIX padrão: pasta "prefix.wine" ao lado do .exe
EXE_PATH="$(realpath "$1" 2>/dev/null || echo "$1")"
EXE_DIR="$(dirname "$EXE_PATH")"
: "${WINEPREFIX:=${EXE_DIR}/prefix.wine}"
export WINEPREFIX

# Cria o prefix se não existir
if [[ ! -d "$WINEPREFIX" ]]; then
    echo ">>> Criando WINEPREFIX em: ${WINEPREFIX}"
    mkdir -p "$WINEPREFIX"
    "$WINE_EXE" wineboot --init 2>/dev/null
    echo ">>> WINEPREFIX criado."
fi

echo ">>> Runner:      ${WINE_VERSION}"
echo ">>> WINEPREFIX: ${WINEPREFIX}"
echo ">>> Executando: $*"

exec "$WINE_EXE" "$@"
EOF

chmod +x /usr/bin/wine
