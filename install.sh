#!/bin/bash

# Script Instalador/Atualizador para o Samba Manager
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Este script baixa o pacote samba-scripts.zip,
#            extrai para ~/.samba-scripts e cria um lançador
#            em /usr/local/bin/samba-script.

# --- Configuração --- #
DOWNLOAD_URL="https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts-test/refs/heads/main/samba_manager.zip"
# Diretório de instalação (oculto na home do usuário)
INSTALL_DIR="$HOME/.samba-scripts"
# Nome do arquivo zip
ZIP_FILE="samba-manager.zip"
# Nome do script lançador
LAUNCHER_NAME="samba-manager"
# Caminho completo do lançador
LAUNCHER_PATH="/usr/local/bin/$LAUNCHER_NAME"
# --- Fim da Configuração --- #

# Cores para mensagens (Correção: Usar printf ou tput para cores é mais seguro, mas para manter a simplicidade, usar \e ou \033 dentro de aspas duplas com echo -e)
RED=\'\e[0;31m\'
GREEN=\'\e[0;32m\'
YELLOW=\'\e[1;33m\'
NC=\'\e[0m\' # Sem Cor

# Função para exibir mensagens de erro e sair
erro() {
    echo -e "${RED}[ERRO] $1${NC}"
    exit 1
}

# Função para exibir mensagens de aviso
aviso() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

# Função para exibir mensagens de sucesso
sucesso() {
    echo -e "${GREEN}[SUCESSO] $1${NC}"
}

# Função para exibir mensagens de informação
info() {
    echo -e "[INFO] $1"
}

# Verificar se o script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    erro "Este script precisa ser executado como root para instalar o lançador em $LAUNCHER_PATH. Use \'sudo $0\'"
fi

# Verificar dependências (wget/curl e unzip)
info "Verificando dependências..."
if command -v wget > /dev/null; then
    DOWNLOAD_CMD="wget -q -O"
elif command -v curl > /dev/null; then
    DOWNLOAD_CMD="curl -s -L -o"
else
    info "\'wget\' ou \'curl\' não encontrado. Tentando instalar \'wget\'..."
    # Correção: Separar comandos para melhor clareza e tratamento de erro
    if ! apt-get update > /dev/null 2>&1; then
        erro "Falha ao atualizar a lista de pacotes (apt-get update)."
    fi
    if ! apt-get install -y wget > /dev/null 2>&1; then
        erro "Falha ao instalar \'wget\'. Instale \'wget\' ou \'curl\' manualmente."
    fi
    DOWNLOAD_CMD="wget -q -O"
fi

if ! command -v unzip > /dev/null; then
    info "\'unzip\' não encontrado. Tentando instalar \'unzip\'..."
    # Correção: Separar comandos para melhor clareza e tratamento de erro
    if ! apt-get update > /dev/null 2>&1; then
        # Aviso: apt-get update já pode ter sido executado acima, mas repetir pode ser necessário se demorar muito
        aviso "Executando apt-get update novamente antes de instalar unzip."
    fi
    if ! apt-get install -y unzip > /dev/null 2>&1; then
        erro "Falha ao instalar \'unzip\'. Instale \'unzip\' manualmente."
    fi
fi
sucesso "Dependências verificadas."

# Criar diretório de instalação se não existir
info "Criando diretório de instalação em $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR" || erro "Falha ao criar o diretório $INSTALL_DIR"

# Baixar o arquivo zip
info "Baixando $ZIP_FILE de $DOWNLOAD_URL..."
# Correção: Verificar o código de saída diretamente
if ! $DOWNLOAD_CMD "$INSTALL_DIR/$ZIP_FILE" "$DOWNLOAD_URL"; then
    erro "Falha ao baixar o arquivo de $DOWNLOAD_URL. Verifique o URL e sua conexão."
fi
sucesso "Download concluído."

# Extrair o arquivo zip
info "Extraindo $ZIP_FILE para $INSTALL_DIR..."
# -o: sobrescrever arquivos existentes sem perguntar
# Correção: Verificar o código de saída diretamente
if ! unzip -o "$INSTALL_DIR/$ZIP_FILE" -d "$INSTALL_DIR/" > /dev/null 2>&1; then
    # Limpar zip em caso de falha na extração para evitar execução parcial
    rm -f "$INSTALL_DIR/$ZIP_FILE"
    erro "Falha ao extrair o arquivo $INSTALL_DIR/$ZIP_FILE."
fi

# Verificar se o script principal existe após extração
# CORREÇÃO: O caminho correto é samba_scripts/, não samba_manager/
MAIN_SCRIPT_PATH="$INSTALL_DIR/samba_scripts/samba_manager.sh"
if [ ! -f "$MAIN_SCRIPT_PATH" ]; then
    # Tentar encontrar em um subdiretório comum se a estrutura do zip variar (mantido como fallback, mas improvável)
    if [ -d "$INSTALL_DIR/samba_manager" ] && [ -f "$INSTALL_DIR/samba_manager/samba_manager.sh" ]; then
        MAIN_SCRIPT_PATH="$INSTALL_DIR/samba_manager/samba_manager.sh"
        aviso "Script principal encontrado em caminho inesperado: $MAIN_SCRIPT_PATH. Verifique a estrutura do zip."
    else
       # Limpar zip e diretório em caso de falha crítica
       rm -f "$INSTALL_DIR/$ZIP_FILE"
       # rm -rf "$INSTALL_DIR" # Opcional: remover tudo se a extração falhou completamente
       erro "Não foi possível encontrar o script principal 	\'$MAIN_SCRIPT_PATH\' após a extração. Instalação abortada."
    fi
fi

info "Script principal encontrado em: $MAIN_SCRIPT_PATH"

# Tornar scripts baixados executáveis
info "Tornando scripts em $INSTALL_DIR executáveis..."
# CORREÇÃO: Ser mais específico para evitar tornar executável arquivos não-script
find "$INSTALL_DIR/samba_scripts" -name '*.sh' -exec chmod +x {} \;

# Criar o script lançador em /usr/local/bin
info "Criando lançador em $LAUNCHER_PATH..."
# Usar cat com EOF para criar o lançador, garantindo que $MAIN_SCRIPT_PATH seja expandido corretamente
cat > "$LAUNCHER_PATH" << EOF
#!/bin/bash
# Lançador para o Samba Manager
# Gerado por install.sh
# Autor: Rafael Schuh (github.com/rafaelhschuh)

# Executa o script principal com sudo, passando quaisquer argumentos
sudo "$MAIN_SCRIPT_PATH" "\$@"
EOF

# Dar permissão de execução ao lançador
chmod +x "$LAUNCHER_PATH" || erro "Falha ao definir permissões de execução para $LAUNCHER_PATH"

# Limpar o arquivo zip baixado
info "Limpando arquivo zip baixado..."
rm -f "$INSTALL_DIR/$ZIP_FILE"

sucesso "Instalação/Atualização do Samba Manager concluída!"
info "Execute o gerenciador com o comando: sudo $LAUNCHER_NAME"

exit 0

