#!/bin/bash

# Script para Gerenciar Usuários do Samba com Tag
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Permite listar usuários com tag global e adicionar novos usuários
#            com tag, associando-os a grupos Samba com tag.

# Diretório dos scripts e locale
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCALE_DIR="$SCRIPT_DIR/locale"
CONFIG_DIR="/etc/samba-manager"
CONFIG_FILE="$CONFIG_DIR/config.conf" # Arquivo para guardar a tag

# Carregar idioma (passado como variável de ambiente ou padrão para en_US)
LANGUAGE=${LANGUAGE:-en_US}
if [ -f "$LOCALE_DIR/${LANGUAGE}.sh" ]; then
    source "$LOCALE_DIR/${LANGUAGE}.sh"
else
    # Fallback para inglês se o arquivo de idioma não for encontrado
    echo "Warning: Language file $LOCALE_DIR/${LANGUAGE}.sh not found. Falling back to English."
    source "$LOCALE_DIR/en_US.sh"
fi

# Arquivo temporário para capturar saída do dialog
OUTPUT="/tmp/samba_users_output.$$"
CHECKLIST_OUTPUT="/tmp/samba_users_checklist.$$"

# Função para limpar e sair
limpar_e_sair() {
    rm -f $OUTPUT $CHECKLIST_OUTPUT
    exit 0
}

# Função para exibir mensagens de erro e sair
erro() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$1" 8 60
    rm -f $OUTPUT $CHECKLIST_OUTPUT
    exit 1
}

# Função para exibir mensagens de sucesso
sucesso_msg() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$1" 8 60
}

# Verificar se dialog está instalado
verificar_dependencias() {
    if ! command -v dialog &> /dev/null; then
        echo "Instalando dialog... / Installing dialog..."
        apt-get update > /dev/null 2>&1 && apt-get install -y dialog > /dev/null 2>&1 || erro "Falha ao instalar dialog / Failed to install dialog"
    fi
    # Verificar se smbpasswd existe (indicativo de Samba instalado)
    if ! command -v smbpasswd &> /dev/null; then
         aviso "$ADD_USER_SAMBA_NOT_FOUND_PROMPT"
         # Não sair, mas avisar que a parte do Samba pode falhar
    fi
}

# Verificar se o script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    dialog --title "Erro / Error" --msgbox "Este script deve ser executado como root para gerenciar usuários. Use \'sudo $0\'\n\nThis script must be run as root to manage users. Use \'sudo $0\'" 8 70
    exit 1
fi

# Verificar dependências
verificar_dependencias

# Carregar tag global do arquivo de configuração
carregar_tag() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    GLOBAL_TAG=${GLOBAL_TAG:-}
    if [ -z "$GLOBAL_TAG" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "A tag global não está definida. Defina a tag primeiro na opção \'Gerenciar Grupos e Permissões\'." 7 70
        limpar_e_sair
    fi
}

# Função para listar usuários com tag
listar_usuarios() {
    carregar_tag
    LISTING_MSG=$(printf "$MANAGE_USERS_LISTING" "$GLOBAL_TAG")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_USERS_LIST" --infobox "$LISTING_MSG" 5 60
    
    OUTPUT_TEXT=""
    USER_FOUND=false
    # Listar usuários do sistema e filtrar pela tag
    while IFS=: read -r name _ uid gid _ home shell; do
        if [[ "$name" == *"@${GLOBAL_TAG}" ]]; then
            USER_FOUND=true
            OUTPUT_TEXT+="Usuário: $name (UID: $uid, GID: $gid)\n"
            # Listar grupos do usuário
            groups_list=$(groups "$name" | cut -d: -f2 | sed 's/^ //')
            OUTPUT_TEXT+="  Grupos: $groups_list\n\n"
        fi
    done < /etc/passwd

    if ! $USER_FOUND; then
        NO_USERS_MSG=$(printf "$MANAGE_USERS_NO_USERS_FOUND" "$GLOBAL_TAG")
        OUTPUT_TEXT="$NO_USERS_MSG"
    fi

    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_USERS_LIST" --msgbox "$OUTPUT_TEXT" 20 70
}

# Função para adicionar novo usuário
adicionar_usuario() {
    carregar_tag

    # Obter nome base
    USER_BASE_NAME=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MANAGE_USERS_NAME" 8 50)
    [ $? -ne 0 ] && return # Cancelado
    if [ -z "$USER_BASE_NAME" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_USERS_NAME_EMPTY" 5 40
        return
    fi
    # Validar nome base (simples)
    if [[ ! "$USER_BASE_NAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_USERS_NAME_INVALID" 5 50
        return
    fi

    # Construir nome final do usuário
    FINAL_USER_NAME="${USER_BASE_NAME}@${GLOBAL_TAG}"
    FINAL_NAME_MSG=$(printf "$MANAGE_USERS_FINAL_NAME" "$FINAL_USER_NAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_USERS_ADD" --infobox "$FINAL_NAME_MSG" 5 60
    sleep 2

    # Verificar se o usuário já existe
    if id "$FINAL_USER_NAME" &>/dev/null; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "O usuário 	'$FINAL_USER_NAME' já existe." 5 50
        return
    fi

    # Listar grupos com a tag para seleção
    GROUP_LIST_OPTIONS=()
    GROUP_NAMES=()
    while IFS=: read -r name _ gid _; do
        if [[ "$name" == *"-smb@${GLOBAL_TAG}" ]]; then
            GROUP_LIST_OPTIONS+=("$name" "" "off")
            GROUP_NAMES+=("$name")
        fi
    done < /etc/group

    SELECTED_GROUPS=()
    if [ ${#GROUP_LIST_OPTIONS[@]} -gt 0 ]; then
        SELECT_GROUPS_MSG=$(printf "$MANAGE_USERS_SELECT_GROUPS" "$FINAL_USER_NAME")
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_USERS_ADD" --checklist "$SELECT_GROUPS_MSG" 20 70 $((${#GROUP_LIST_OPTIONS[@]}/3)) "${GROUP_LIST_OPTIONS[@]}" 2> $CHECKLIST_OUTPUT
        
        exit_status=$?
        SELECTED_GROUPS_STR=$(cat $CHECKLIST_OUTPUT)
        rm -f $CHECKLIST_OUTPUT
        
        if [ $exit_status -ne 0 ]; then
            return # Cancelado
        fi
        
        # Converter string de grupos selecionados para array
        IFS=	'"' read -r -a SELECTED_GROUPS <<< "$SELECTED_GROUPS_STR"
        temp_groups=()
        for group in "${SELECTED_GROUPS[@]}"; do
            trimmed_group=$(echo "$group" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim
            if [ -n "$trimmed_group" ]; then
                temp_groups+=("$trimmed_group")
            fi
        done
        SELECTED_GROUPS=("${temp_groups[@]}")
    else
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "Nenhum grupo com a tag 	'$GLOBAL_TAG' encontrado para adicionar o usuário." 6 60
    fi

    # Criar o usuário sem diretório home
    CREATING_MSG=$(printf "$MANAGE_USERS_CREATING" "$FINAL_USER_NAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_USERS_ADD" --infobox "$CREATING_MSG" 5 60
    useradd -M -N -s /usr/sbin/nologin "$FINAL_USER_NAME"
    if [ $? -ne 0 ]; then
        erro "Falha ao criar o usuário 	'$FINAL_USER_NAME' no sistema."
    fi

    # Adicionar usuário aos grupos selecionados
    if [ ${#SELECTED_GROUPS[@]} -gt 0 ]; then
        for group in "${SELECTED_GROUPS[@]}"; do
            echo "Adicionando $FINAL_USER_NAME ao grupo $group..."
            usermod -a -G "$group" "$FINAL_USER_NAME"
        done
    fi
    sleep 1

    # Definir senha do sistema
    SYS_PASS_TITLE=$(printf "$MANAGE_USERS_SYS_PASS" "$FINAL_USER_NAME")
    while true; do
        SYS_PASS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$SYS_PASS_TITLE\n$ADD_USER_SYS_PASS_PROMPT" 8 60)
        [ $? -ne 0 ] && erro "$MSG_CANCELED"
        SYS_PASS_CONFIRM=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$ADD_USER_SYS_PASS_CONFIRM" 8 60)
        [ $? -ne 0 ] && erro "$MSG_CANCELED"
        
        if [ "$SYS_PASS" != "$SYS_PASS_CONFIRM" ] || [ -z "$SYS_PASS" ]; then
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$ADD_USER_PASS_MISMATCH" 5 50
        else
            echo "$FINAL_USER_NAME:$SYS_PASS" | chpasswd
            if [ $? -eq 0 ]; then
                echo "[INFO] Senha do sistema definida."
                break
            else
                erro "Falha ao definir a senha do sistema para $FINAL_USER_NAME."
            fi
        fi
    done

    # Definir senha do Samba
    if command -v smbpasswd &> /dev/null; then
        SAMBA_PASS_TITLE=$(printf "$MANAGE_USERS_SAMBA_PASS" "$FINAL_USER_NAME")
        while true; do
            SAMBA_PASS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$SAMBA_PASS_TITLE\n$ADD_USER_SAMBA_PASS_PROMPT" 8 60)
            [ $? -ne 0 ] && erro "$MSG_CANCELED"
            SAMBA_PASS_CONFIRM=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$ADD_USER_SAMBA_PASS_CONFIRM" 8 60)
            [ $? -ne 0 ] && erro "$MSG_CANCELED"
            
            if [ "$SAMBA_PASS" != "$SAMBA_PASS_CONFIRM" ] || [ -z "$SAMBA_PASS" ]; then
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$ADD_USER_PASS_MISMATCH" 5 50
            else
                (echo "$SAMBA_PASS"; echo "$SAMBA_PASS") | smbpasswd -a -s "$FINAL_USER_NAME"
                if [ $? -eq 0 ]; then
                    echo "[INFO] Senha do Samba definida."
                    break
                else
                    # Tentar habilitar o usuário primeiro, caso já exista no samba mas esteja desabilitado
                    smbpasswd -e "$FINAL_USER_NAME" > /dev/null 2>&1
                    (echo "$SAMBA_PASS"; echo "$SAMBA_PASS") | smbpasswd -s "$FINAL_USER_NAME"
                     if [ $? -eq 0 ]; then
                         echo "[INFO] Senha do Samba definida após habilitar usuário."
                         break
                     else
                         erro "Falha ao definir a senha do Samba para $FINAL_USER_NAME. Verifique se o Samba está configurado corretamente."
                     fi
                fi
            fi
        done
    else
         dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "Comando smbpasswd não encontrado. A senha do Samba não foi definida. Instale/configure o Samba primeiro." 8 70
    fi

    SUCCESS_MSG=$(printf "$MANAGE_USERS_SUCCESS" "$FINAL_USER_NAME")
    sucesso_msg "$SUCCESS_MSG"
}

# Menu de Gerenciamento de Usuários
menu_gerenciar_usuarios() {
    while true; do
        dialog --clear --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
               --title "$MANAGE_USERS_TITLE" \
               --menu "$MANAGE_USERS_CHOOSE" 15 60 3 \
               1 "$MANAGE_USERS_LIST" \
               2 "$MANAGE_USERS_ADD" \
               3 "$MSG_EXIT" 2> $OUTPUT
        
        exit_status=$?
        choice=$(cat $OUTPUT)
        rm -f $OUTPUT
        
        if [ $exit_status -ne 0 ]; then
            break # Voltar ao menu principal
        fi
        
        case $choice in
            1) listar_usuarios ;; 
            2) adicionar_usuario ;; 
            3) break ;; # Voltar ao menu principal
            *) dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "Opção inválida / Invalid option" 5 40 ;;
        esac
    done
}

# Iniciar menu de gerenciamento de usuários
menu_gerenciar_usuarios

# Limpar e sair
limpar_e_sair

