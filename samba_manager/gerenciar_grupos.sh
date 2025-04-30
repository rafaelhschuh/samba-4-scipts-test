#!/bin/bash

# Script para Gerenciar Grupos e Permissões do Samba
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Permite definir tag global, criar grupos com tag,
#            modificar permissões de pastas compartilhadas para grupos com tag,
#            e listar grupos com tag e seus membros.

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
OUTPUT="/tmp/samba_groups_output.$$"
CHECKLIST_OUTPUT="/tmp/samba_groups_checklist.$$"

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

# Verificar se dialog e setfacl/getfacl estão instalados
verificar_dependencias() {
    if ! command -v dialog &> /dev/null; then
        echo "Instalando dialog... / Installing dialog..."
        apt-get update > /dev/null 2>&1 && apt-get install -y dialog > /dev/null 2>&1 || erro "Falha ao instalar dialog / Failed to install dialog"
    fi
    if ! command -v setfacl &> /dev/null || ! command -v getfacl &> /dev/null; then
        echo "Instalando acl... / Installing acl..."
        apt-get update > /dev/null 2>&1 && apt-get install -y acl > /dev/null 2>&1 || erro "Falha ao instalar acl (setfacl/getfacl) / Failed to install acl (setfacl/getfacl)"
    fi
}

# Verificar se o script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    dialog --title "Erro / Error" --msgbox "Este script deve ser executado como root para gerenciar grupos e permissões. Use \'sudo $0\'\n\nThis script must be run as root to manage groups and permissions. Use \'sudo $0\'" 8 70
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
}

# Salvar tag global no arquivo de configuração
salvar_tag() {
    mkdir -p "$CONFIG_DIR" # Garante que o diretório exista
    echo "GLOBAL_TAG=\"$1\"" > "$CONFIG_FILE"
}

# Função para definir/ver a tag global
gerenciar_tag() {
    carregar_tag
    CURRENT_TAG_MSG=$(printf "$MANAGE_GROUPS_TAG_CURRENT" "$GLOBAL_TAG")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_SET_TAG" --inputbox "$CURRENT_TAG_MSG\n\n$MANAGE_GROUPS_TAG_NEW" 12 60 "$GLOBAL_TAG" 2> $OUTPUT
    
    exit_status=$?
    NEW_TAG=$(cat $OUTPUT)
    rm -f $OUTPUT
    
    if [ $exit_status -ne 0 ]; then
        return # Cancelado
    fi
    
    if [ -z "$NEW_TAG" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_GROUPS_TAG_EMPTY" 5 40
        return
    fi
    
    # Validar tag (simples)
    if [[ ! "$NEW_TAG" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_GROUPS_TAG_INVALID" 5 50
        return
    fi
    
    salvar_tag "$NEW_TAG"
    SUCCESS_MSG=$(printf "$MANAGE_GROUPS_TAG_SUCCESS" "$NEW_TAG")
    sucesso_msg "$SUCCESS_MSG"
}

# Função para obter lista de compartilhamentos e seus caminhos
obter_compartilhamentos() {
    SHARES=()
    PATHS=()
    # Analisar smb.conf para encontrar seções de compartilhamento e seus caminhos
    # Ignorar seções globais como [global], [homes], [printers]
    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') # Trim whitespace
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ ! "$line" =~ ^\[(global|homes|printers)\]$ ]]; then
            current_share=$(echo "$line" | tr -d '[]')
            current_path=""
        elif [[ -n "$current_share" ]] && [[ "$line" =~ ^[[:space:]]*path[[:space:]]*= ]]; then
            current_path=$(echo "$line" | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -n "$current_share" ] && [ -n "$current_path" ] && [ -d "$current_path" ]; then
                SHARES+=("$current_share")
                PATHS+=("$current_path")
            fi
            current_share=""
            current_path=""
        fi
    done < /etc/samba/smb.conf
}

# Função para criar novo grupo
criar_grupo() {
    carregar_tag
    if [ -z "$GLOBAL_TAG" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "A tag global não está definida. Defina a tag primeiro na opção 1." 6 60
        return
    fi

    # Obter nome base
    GROUP_BASE_NAME=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MANAGE_GROUPS_NAME" 8 50)
    [ $? -ne 0 ] && return # Cancelado
    if [ -z "$GROUP_BASE_NAME" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_GROUPS_NAME_EMPTY" 5 40
        return
    fi
    # Validar nome base (simples)
    if [[ ! "$GROUP_BASE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MANAGE_GROUPS_NAME_INVALID" 5 50
        return
    fi

    # Construir nome final do grupo
    FINAL_GROUP_NAME="${GROUP_BASE_NAME}-smb@${GLOBAL_TAG}"
    FINAL_NAME_MSG=$(printf "$MANAGE_GROUPS_FINAL_NAME" "$FINAL_GROUP_NAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_CREATE" --infobox "$FINAL_NAME_MSG" 5 60
    sleep 2

    # Verificar se o grupo já existe
    if getent group "$FINAL_GROUP_NAME" > /dev/null; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "O grupo '$FINAL_GROUP_NAME' já existe." 5 50
        return
    fi

    # Obter compartilhamentos
    obter_compartilhamentos
    if [ ${#SHARES[@]} -eq 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "$MANAGE_GROUPS_NO_SHARES" 6 60
        # Continuar mesmo sem compartilhamentos para criar o grupo?
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_CREATE" --yesno "Nenhum compartilhamento encontrado. Deseja criar o grupo '$FINAL_GROUP_NAME' mesmo assim (sem aplicar permissões de pasta)?" 8 70
        if [ $? -ne 0 ]; then
            return
        fi
        SELECTED_PATHS=()
    else
        # Montar opções para checklist
        CHECKLIST_OPTIONS=()
        for i in "${!SHARES[@]}"; do
            CHECKLIST_OPTIONS+=("${PATHS[$i]}" "${SHARES[$i]} (${PATHS[$i]})" "off")
        done
        
        SELECT_FOLDERS_MSG=$(printf "$MANAGE_GROUPS_SELECT_FOLDERS" "$FINAL_GROUP_NAME")
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_CREATE" --checklist "$SELECT_FOLDERS_MSG" 20 70 ${#SHARES[@]} "${CHECKLIST_OPTIONS[@]}" 2> $CHECKLIST_OUTPUT
        
        exit_status=$?
        SELECTED_PATHS_STR=$(cat $CHECKLIST_OUTPUT)
        rm -f $CHECKLIST_OUTPUT
        
        if [ $exit_status -ne 0 ]; then
            return # Cancelado
        fi
        
        # Converter string de caminhos selecionados para array
        IFS='"' read -r -a SELECTED_PATHS <<< "$SELECTED_PATHS_STR"
        # Remover elementos vazios resultantes da divisão
        temp_paths=()
        for path in "${SELECTED_PATHS[@]}"; do
            trimmed_path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim
            if [ -n "$trimmed_path" ]; then
                temp_paths+=("$trimmed_path")
            fi
        done
        SELECTED_PATHS=("${temp_paths[@]}")
    fi

    # Criar o grupo
    CREATING_MSG=$(printf "$MANAGE_GROUPS_CREATING" "$FINAL_GROUP_NAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_CREATE" --infobox "$CREATING_MSG" 5 60
    groupadd "$FINAL_GROUP_NAME"
    if [ $? -ne 0 ]; then
        erro "Falha ao criar o grupo '$FINAL_GROUP_NAME'."
    fi

    # Aplicar permissões ACL (exemplo: rwx para o grupo)
    # IMPORTANTE: Definir permissões padrão também para novos arquivos/pastas
    for path in "${SELECTED_PATHS[@]}"; do
        echo "Aplicando ACLs para $FINAL_GROUP_NAME em $path..."
        # Permissões no diretório atual
        setfacl -m "g:$FINAL_GROUP_NAME:rwx" "$path"
        # Permissões padrão para novos itens dentro do diretório
        setfacl -d -m "g:$FINAL_GROUP_NAME:rwx" "$path"
        # Opcional: Definir dono/grupo se necessário (ex: chown root:"$FINAL_GROUP_NAME" "$path")
        # Opcional: Ajustar permissões base (ex: chmod g+s "$path")
    done
    sleep 1

    SUCCESS_MSG=$(printf "$MANAGE_GROUPS_SUCCESS" "$FINAL_GROUP_NAME")
    sucesso_msg "$SUCCESS_MSG"
}

# Função para modificar permissões de grupo existente (INCOMPLETO - Esboço)
modificar_grupo() {
    carregar_tag
    if [ -z "$GLOBAL_TAG" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "A tag global não está definida. Defina a tag primeiro na opção 1." 6 60
        return
    fi

    # Listar grupos com a tag
    GROUP_LIST=()
    while IFS=: read -r name _ gid _; do
        if [[ "$name" == *"-smb@${GLOBAL_TAG}" ]]; then
            GROUP_LIST+=("$name" "")
        fi
    done < /etc/group

    if [ ${#GROUP_LIST[@]} -eq 0 ]; then
        NO_GROUPS_MSG=$(printf "$MANAGE_GROUPS_NO_GROUPS_FOUND" "$GLOBAL_TAG")
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_MODIFY" --msgbox "$NO_GROUPS_MSG" 6 60
        return
    fi

    # Selecionar grupo
    SELECT_MODIFY_MSG=$(printf "$MANAGE_GROUPS_SELECT_MODIFY")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_MODIFY" --menu "$SELECT_MODIFY_MSG" 15 60 ${#GROUP_LIST[@]} "${GROUP_LIST[@]}" 2> $OUTPUT
    
    exit_status=$?
    SELECTED_GROUP=$(cat $OUTPUT)
    rm -f $OUTPUT
    
    if [ $exit_status -ne 0 ] || [ -z "$SELECTED_GROUP" ]; then
        return # Cancelado ou vazio
    fi

    # Obter compartilhamentos
    obter_compartilhamentos
    if [ ${#SHARES[@]} -eq 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "$MANAGE_GROUPS_NO_SHARES" 6 60
        return
    fi

    # Obter permissões atuais e montar checklist
    CHECKLIST_OPTIONS=()
    for i in "${!SHARES[@]}"; do
        path="${PATHS[$i]}"
        share="${SHARES[$i]}"
        # Verificar se o grupo tem permissão (simplificado - verifica se existe entrada ACL)
        if getfacl "$path" | grep -q "^group:$SELECTED_GROUP:"; then
            CHECKLIST_OPTIONS+=("$path" "$share ($path)" "on")
        else
            CHECKLIST_OPTIONS+=("$path" "$share ($path)" "off")
        fi
    done

    SELECT_FOLDERS_MSG=$(printf "$MANAGE_GROUPS_SELECT_FOLDERS" "$SELECTED_GROUP")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_MODIFY" --checklist "$SELECT_FOLDERS_MSG" 20 70 ${#SHARES[@]} "${CHECKLIST_OPTIONS[@]}" 2> $CHECKLIST_OUTPUT
    
    exit_status=$?
    SELECTED_PATHS_STR=$(cat $CHECKLIST_OUTPUT)
    rm -f $CHECKLIST_OUTPUT
    
    if [ $exit_status -ne 0 ]; then
        return # Cancelado
    fi
    
    # Converter string de caminhos selecionados para array
    IFS='"' read -r -a NEWLY_SELECTED_PATHS <<< "$SELECTED_PATHS_STR"
    temp_paths=()
    for path in "${NEWLY_SELECTED_PATHS[@]}"; do
        trimmed_path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim
        if [ -n "$trimmed_path" ]; then
            temp_paths+=("$trimmed_path")
        fi
    done
    NEWLY_SELECTED_PATHS=("${temp_paths[@]}")

    # Aplicar/Remover permissões
    MODIFYING_MSG=$(printf "$MANAGE_GROUPS_MODIFYING" "$SELECTED_GROUP")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_MODIFY" --infobox "$MODIFYING_MSG" 5 60
    
    for i in "${!PATHS[@]}"; do
        path="${PATHS[$i]}"
        should_have_access=false
        for selected_path in "${NEWLY_SELECTED_PATHS[@]}"; do
            if [ "$path" == "$selected_path" ]; then
                should_have_access=true
                break
            fi
        done

        if $should_have_access; then
            echo "Garantindo ACLs para $SELECTED_GROUP em $path..."
            setfacl -m "g:$SELECTED_GROUP:rwx" "$path"
            setfacl -d -m "g:$SELECTED_GROUP:rwx" "$path"
        else
            echo "Removendo ACLs para $SELECTED_GROUP em $path..."
            setfacl -x "g:$SELECTED_GROUP" "$path"
            setfacl -d -x "g:$SELECTED_GROUP" "$path"
        fi
    done
    sleep 1

    SUCCESS_MSG=$(printf "$MANAGE_GROUPS_MODIFY_SUCCESS" "$SELECTED_GROUP")
    sucesso_msg "$SUCCESS_MSG"
}

# Função para listar grupos e usuários (INCOMPLETO - Esboço)
listar_grupos_usuarios() {
    carregar_tag
    if [ -z "$GLOBAL_TAG" ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "A tag global não está definida. Defina a tag primeiro na opção 1." 6 60
        return
    fi

    LISTING_MSG=$(printf "$MANAGE_GROUPS_LISTING" "$GLOBAL_TAG")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_LIST" --infobox "$LISTING_MSG" 5 60
    
    OUTPUT_TEXT=""
    GROUP_FOUND=false
    while IFS=: read -r name _ gid members; do
        if [[ "$name" == *"-smb@${GLOBAL_TAG}" ]]; then
            GROUP_FOUND=true
            OUTPUT_TEXT+="Grupo: $name (GID: $gid)\n"
            if [ -n "$members" ]; then
                OUTPUT_TEXT+="  Membros: $members\n"
            else
                OUTPUT_TEXT+="  Membros: (nenhum)\n"
            fi
            OUTPUT_TEXT+="\n"
        fi
    done < /etc/group

    if ! $GROUP_FOUND; then
        NO_GROUPS_MSG=$(printf "$MANAGE_GROUPS_NO_GROUPS_FOUND" "$GLOBAL_TAG")
        OUTPUT_TEXT="$NO_GROUPS_MSG"
    fi

    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MANAGE_GROUPS_LIST" --msgbox "$OUTPUT_TEXT" 20 70
}

# Menu de Gerenciamento de Grupos
menu_gerenciar_grupos() {
    while true; do
        dialog --clear --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
               --title "$MANAGE_GROUPS_TITLE" \
               --menu "$MANAGE_GROUPS_CHOOSE" 15 60 5 \
               1 "$MANAGE_GROUPS_SET_TAG" \
               2 "$MANAGE_GROUPS_CREATE" \
               3 "$MANAGE_GROUPS_MODIFY" \
               4 "$MANAGE_GROUPS_LIST" \
               5 "$MSG_EXIT" 2> $OUTPUT
        
        exit_status=$?
        choice=$(cat $OUTPUT)
        rm -f $OUTPUT
        
        if [ $exit_status -ne 0 ]; then
            break # Voltar ao menu principal
        fi
        
        case $choice in
            1) gerenciar_tag ;; 
            2) criar_grupo ;; 
            3) modificar_grupo ;; 
            4) listar_grupos_usuarios ;; 
            5) break ;; # Voltar ao menu principal
            *) dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "Opção inválida / Invalid option" 5 40 ;;
        esac
    done
}

# Iniciar menu de gerenciamento de grupos
menu_gerenciar_grupos

# Limpar e sair
limpar_e_sair

