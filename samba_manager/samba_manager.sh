#!/bin/bash

# Script principal para gerenciamento do Samba com suporte a múltiplos idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025 (Refatorado em Maio 2025)
# Descrição: Interface principal para gerenciar o servidor Samba com suporte a PT-BR e EN-US

# --- Configuração e Inicialização ---

# Diretório dos scripts e libs
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Arquivo temporário para capturar saída do dialog
OUTPUT="/tmp/samba_manager_output.$$"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    echo "ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado."
    exit 1
fi

log_message "Samba Manager iniciado."

# --- Funções Auxiliares ---

# Função para limpar e sair
limpar_e_sair() {
    log_message "Encerrando Samba Manager."
    rm -f $OUTPUT
    clear
    exit 0
}

# Função para verificar dependências
verificar_dependencias() {
    log_message "Verificando dependência 'dialog'."
    if ! command -v dialog &> /dev/null; then
        log_message "Dependência 'dialog' não encontrada. Tentando instalar..."
        echo "Instalando dialog... / Installing dialog..."
        if sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y dialog > /dev/null 2>&1; then
            log_message "Dependência 'dialog' instalada com sucesso."
        else
            log_message "ERRO: Falha ao instalar 'dialog'."
            echo "Falha ao instalar 'dialog'. Por favor, instale manualmente e execute o script novamente."
            echo "Failed to install 'dialog'. Please install it manually and run the script again."
            exit 1
        fi
    else
        log_message "Dependência 'dialog' encontrada."
    fi
}

# Função para verificar privilégios de root
verificar_root() {
    log_message "Verificando privilégios de root."
    if [ "$(id -u)" != "0" ]; then
        log_message "ERRO: Script não executado como root."
        dialog --title "Erro / Error" --msgbox "Este script deve ser executado como root. Use 'sudo $0'\n\nThis script must be run as root. Use 'sudo $0'" 8 60
        limpar_e_sair
    fi
    log_message "Executando como root."
}

# Função para selecionar o idioma
selecionar_idioma() {
    log_message "Iniciando seleção de idioma."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
           --title "Samba Manager - Seleção de Idioma / Language Selection" \
           --menu "Selecione o idioma / Select language:" 12 60 2 \
           "pt_BR" "Português (Brasil)" \
           "en_US" "English (US)" 2> $OUTPUT
    
    local exit_status=$?
    LANGUAGE=$(cat $OUTPUT)
    rm -f $OUTPUT
    
    if [ $exit_status -ne 0 ]; then
        log_message "Seleção de idioma cancelada pelo usuário."
        limpar_e_sair
    fi
    
    log_message "Tentando carregar arquivo de idioma: $LANGUAGE"
    if [ -f "$LOCALE_DIR/${LANGUAGE}.sh" ]; then
        source "$LOCALE_DIR/${LANGUAGE}.sh"
        log_message "Arquivo de idioma '$LANGUAGE' carregado com sucesso."
    else
        log_message "ERRO: Arquivo de idioma '$LOCALE_DIR/${LANGUAGE}.sh' não encontrado."
        dialog --title "Error / Erro" --msgbox "Language file not found / Arquivo de idioma não encontrado: $LANGUAGE" 6 60
        limpar_e_sair
    fi
}

# --- Menu Principal ---

menu_principal() {
    while true; do
        log_message "Exibindo menu principal."
        dialog --clear --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
               --title "$MENU_TITLE" \
               --menu "$MENU_CHOOSE" 20 75 7 \
               1 "$MENU_INSTALL_UPDATE_SAMBA" \
               2 "$MENU_UPDATE_MANAGER" \
               3 "$MENU_MANAGE_GROUPS" \
               4 "$MENU_MANAGE_USERS" \
               5 "$MENU_CRITICAL_AREA" \
               6 "$MSG_ABOUT" \
               7 "$MSG_EXIT" 2> $OUTPUT
        
        local exit_status=$?
        local choice=$(cat $OUTPUT)
        rm -f $OUTPUT
        
        if [ $exit_status -ne 0 ]; then
            log_message "Menu principal cancelado pelo usuário."
            limpar_e_sair
        fi
        
        log_message "Opção selecionada no menu principal: $choice"
        case $choice in
            1)
                log_message "Chamando script: instalar_atualizar_samba.sh"
                LANGUAGE=$LANGUAGE "$SCRIPT_DIR/instalar_atualizar_samba.sh"
                ;;
            2)
                log_message "Chamando script: atualizar_manager.sh"
                LANGUAGE=$LANGUAGE "$SCRIPT_DIR/atualizar_manager.sh"
                ;;
            3)
                log_message "Chamando script: gerenciar_grupos.sh"
                LANGUAGE=$LANGUAGE "$SCRIPT_DIR/gerenciar_grupos.sh"
                ;;
            4)
                log_message "Chamando script: gerenciar_usuarios.sh"
                LANGUAGE=$LANGUAGE "$SCRIPT_DIR/gerenciar_usuarios.sh"
                ;;
            5)
                log_message "Chamando script: area_critica.sh"
                LANGUAGE=$LANGUAGE "$SCRIPT_DIR/area_critica.sh"
                ;;
            6)
                log_message "Exibindo informações 'Sobre'."
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
                       --title "$MSG_ABOUT" \
                       --msgbox "$ABOUT_TEXT" 12 60
                ;;
            7)
                log_message "Usuário selecionou sair."
                limpar_e_sair
                ;;
            *)
                log_message "Opção inválida selecionada: $choice"
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "Opção inválida / Invalid option" 5 40
                ;;
        esac
        log_message "Retornando ao menu principal após ação: $choice"
    done
}

# --- Execução Principal ---

# Verificar dependências
verificar_dependencias

# Verificar se o script está sendo executado como root
verificar_root

# Selecionar idioma
selecionar_idioma

# Exibir tela de boas-vindas
log_message "Exibindo tela de boas-vindas."
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
       --title "$MSG_WELCOME" \
       --msgbox "$MSG_WELCOME_DESC\n\n$MSG_CONTINUE" 12 60

# Iniciar o menu principal
menu_principal

# Limpar e sair (fallback, caso o loop do menu principal termine inesperadamente)
limpar_e_sair

