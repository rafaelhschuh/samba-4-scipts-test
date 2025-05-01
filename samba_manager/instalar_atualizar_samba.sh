#!/bin/bash

# Script de Instalação/Atualização do Samba 4 no Debian com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025 (Refatorado em Maio 2025)
# Descrição: Realiza a instalação/configuração do Samba 4 (AD DC, Membro, Servidor de Arquivos).

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    echo "ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado."
    # Tentativa de log antes de sair, pode não funcionar se o arquivo de log não existir
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado." >> "$LOG_FILE" 2>/dev/null
    exit 1
fi

log_message "Iniciando script instalar_atualizar_samba.sh"

# Carregar idioma (passado como variável de ambiente ou padrão para en_US)
LANGUAGE=${LANGUAGE:-en_US}
log_message "Verificando arquivo de idioma: $LANGUAGE"
if [ -f "$LOCALE_DIR/${LANGUAGE}.sh" ]; then
    source "$LOCALE_DIR/${LANGUAGE}.sh"
    log_message "Arquivo de idioma '$LANGUAGE' carregado."
else
    log_message "AVISO: Arquivo de idioma '$LOCALE_DIR/${LANGUAGE}.sh' não encontrado. Usando en_US como padrão."
    echo "Warning: Language file $LOCALE_DIR/${LANGUAGE}.sh not found. Falling back to English."
    if [ -f "$LOCALE_DIR/en_US.sh" ]; then
        source "$LOCALE_DIR/en_US.sh"
        LANGUAGE="en_US"
    else
        log_message "ERRO CRÍTICO: Arquivo de idioma padrão 'en_US.sh' não encontrado."
        echo "CRITICAL ERROR: Default language file en_US.sh not found."
        exit 1
    fi
fi

# Arquivo temporário para capturar saída do dialog
OUTPUT="/tmp/samba_install_output.$$"
INSTALL_LOG="/tmp/samba_install_detailed.log"
rm -f "$INSTALL_LOG"

# --- Funções Auxiliares ---

# Função para exibir mensagens de erro, logar e sair
erro() {
    local msg="$1"
    log_message "ERRO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$msg" 8 60
    rm -f $OUTPUT "$INSTALL_LOG"
    exit 1
}

# Função para exibir mensagens de aviso e logar
aviso() {
    local msg="$1"
    log_message "AVISO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "$msg" 8 60
}

# Função para exibir mensagens de sucesso e logar
sucesso_msg() {
    local msg="$1"
    log_message "SUCESSO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$msg" 8 60
}

# Função para verificar se o script está sendo executado como root
verificar_root() {
    log_message "Verificando privilégios de root."
    if [ "$(id -u)" != "0" ]; then
        erro "Este script deve ser executado como root. Use 'sudo $0'\n\nThis script must be run as root. Use 'sudo $0'"
    fi
    log_message "Executando como root."
}

# Função para verificar a versão do Debian
verificar_debian() {
    log_message "Verificando sistema operacional."
    if [ ! -f /etc/debian_version ]; then
        erro "Este script foi projetado para ser executado no Debian. Sistema operacional não suportado.\n\nThis script is designed to run on Debian. Unsupported operating system."
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    log_message "Versão do Debian detectada: $DEBIAN_VERSION"
    
    if [ "$DEBIAN_VERSION" -lt 10 ]; then
        log_message "Versão do Debian ($DEBIAN_VERSION) é anterior à 10. Exibindo aviso."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --yesno "Este script foi testado no Debian 10 (Buster) ou superior. Versões mais antigas podem não funcionar corretamente. Deseja continuar?\n\nThis script was tested on Debian 10 (Buster) or later. Older versions may not work correctly. Do you want to continue?" 8 70
        if [ $? -ne 0 ]; then
            log_message "Usuário cancelou devido à versão do Debian."
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            rm -f $OUTPUT "$INSTALL_LOG"
            exit 0
        fi
        log_message "Usuário decidiu continuar com versão antiga do Debian."
    fi
}

# Função para atualizar o sistema com dialog
atualizar_sistema() {
    log_message "Iniciando atualização do sistema."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --infobox "$INSTALL_UPDATING_REPOS" 5 50
    if ! sudo apt-get update >> "$INSTALL_LOG" 2>&1; then
        log_message "ERRO: Falha ao executar apt-get update."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox "$INSTALL_LOG" 20 70
        erro "Falha ao atualizar listas de pacotes / Failed to update package lists"
    fi
    log_message "Listas de pacotes atualizadas."
    
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --infobox "$INSTALL_UPDATING_PACKAGES" 5 70
    # Usar DEBIAN_FRONTEND=noninteractive para evitar prompts durante o upgrade
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$INSTALL_LOG" 2>&1; then
        log_message "AVISO: Falha ao executar apt-get upgrade. Verifique o log '$INSTALL_LOG'."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox "$INSTALL_LOG" 20 70
        aviso "Falha ao atualizar pacotes. Alguns pacotes podem não ter sido atualizados. Verifique o log.\n\nFailed to upgrade packages. Some packages may not have been updated. Check the log."
    else
        log_message "Pacotes do sistema atualizados com sucesso."
    fi
}

# Função para instalar dependências básicas com dialog
instalar_dependencias() {
    log_message "Iniciando instalação de dependências básicas."
    DEPENDENCIAS=("dialog" "acl" "attr" "wget" "curl" "net-tools" "dnsutils" \
                  "python3-setproctitle" "python3-dnspython" "python3-markdown" \
                  "python3-crypto" "gdb" "pkg-config" "libjansson-dev")
    
    local dep_log="/tmp/dependency_install.log"
    rm -f "$dep_log"
    touch "$dep_log"
    
    log_message "Verificando/Instalando dependências: ${DEPENDENCIAS[*]}"
    
    # Verificar se o DEBIAN_FRONTEND está definido para noninteractive
    export DEBIAN_FRONTEND=noninteractive
    
    # Atualizar lista de pacotes primeiro (silenciosamente)
    sudo apt-get update > /dev/null 2>&1
    
    ( 
      echo "$INSTALL_DEPENDENCIES_INFO"
      COUNT=0
      TOTAL=${#DEPENDENCIAS[@]}
      for dep in "${DEPENDENCIAS[@]}"; do
          PERCENT=$(( ($COUNT * 100) / $TOTAL ))
          echo $PERCENT
          echo "XXX"
          echo "Verificando/Instalando $dep... ($(($COUNT + 1))/$TOTAL)"
          echo "XXX"
          
          # Verificar se o pacote já está instalado
          if dpkg -l | grep -q "^ii  $dep "; then
              echo "INFO: $dep já está instalado, pulando." >> "$dep_log"
          else
              # Instalar o pacote apenas se não estiver instalado
              if ! sudo apt-get install -y --no-install-recommends "$dep" >> "$dep_log" 2>&1; then
                  echo "ERRO: Falha ao instalar $dep. Verifique o log." >> "$dep_log"
              else
                  echo "INFO: $dep instalado com sucesso." >> "$dep_log"
              fi
          fi
          COUNT=$(($COUNT + 1))
      done
      echo 100
      echo "XXX"
      echo "Verificação/Instalação de dependências concluída."
      echo "Dependency verification/installation complete."
      echo "XXX"
      sleep 1 # Pequena pausa para o usuário ver 100%
    ) | dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_DEPENDENCIES" --gauge "$INSTALL_DEPENDENCIES_INFO" 10 70 0

    # Verificar se houve erros reais no log
    if grep -q "ERRO:" "$dep_log"; then
        log_message "AVISO: Erros encontrados durante a instalação de dependências. Ver log '$dep_log'."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox "$dep_log" 20 70
        aviso "Alguns pacotes podem não ter sido instalados corretamente. O script tentará continuar.\n\nSome packages may not have been installed correctly. The script will try to continue."
    else
        log_message "Dependências básicas verificadas/instaladas com sucesso."
        sucesso_msg "$INSTALL_DEPENDENCIES_SUCCESS"
    fi
    
    # Restaurar o DEBIAN_FRONTEND
    unset DEBIAN_FRONTEND
    
    # rm -f "$dep_log" # Opcional: manter o log para depuração
}

# Função para instalar o Samba 4 como pacote com dialog
instalar_samba_pacote() {
    log_message "Iniciando instalação dos pacotes Samba."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_SAMBA" --infobox "$INSTALL_SAMBA_INFO" 5 60
    
    # Definir DEBIAN_FRONTEND para noninteractive para evitar prompts
    export DEBIAN_FRONTEND=noninteractive
    
    local samba_log="/tmp/samba_package_install.log"
    rm -f "$samba_log"
    
    # Instalar pacotes Samba com opção --no-install-recommends
    log_message "Executando: apt-get install -y --no-install-recommends samba samba-common samba-dsdb-modules samba-vfs-modules winbind libpam-winbind libnss-winbind krb5-config krb5-user"
    if ! sudo apt-get install -y --no-install-recommends samba samba-common samba-dsdb-modules samba-vfs-modules \
        winbind libpam-winbind libnss-winbind krb5-config krb5-user >> "$samba_log" 2>&1; then
        log_message "AVISO: Erros encontrados durante a instalação dos pacotes Samba. Ver log '$samba_log'."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox "$samba_log" 20 70
        aviso "Alguns componentes do Samba podem não ter sido instalados corretamente. O script tentará continuar.\n\nSome Samba components may not have been installed correctly. The script will try to continue."
    else
        log_message "Pacotes Samba instalados com sucesso."
    fi
    
    # Restaurar o DEBIAN_FRONTEND
    unset DEBIAN_FRONTEND
    
    # Parar e desabilitar serviços para evitar conflitos antes do provisionamento/join
    log_message "Parando e desabilitando serviços Samba padrão (smbd, nmbd, winbind)."
    sudo systemctl stop smbd nmbd winbind > /dev/null 2>&1
    sudo systemctl disable smbd nmbd winbind > /dev/null 2>&1
    log_message "Serviços Samba padrão parados e desabilitados."
}

# Função para configurar o NTP com dialog
configurar_ntp() {
    log_message "Iniciando configuração do NTP."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_NTP" --infobox "$INSTALL_NTP_INFO" 5 50
    
    log_message "Instalando pacote ntp."
    if ! sudo apt-get install -y ntp >> "$INSTALL_LOG" 2>&1; then
        log_message "ERRO: Falha ao instalar NTP."
        erro "Falha ao instalar NTP / Failed to install NTP"
    fi
    
    log_message "Configurando /etc/ntp.conf."
    # Configurar NTP para sincronizar com servidores (usar pool.ntp.org para global)
    cat << EOF | sudo tee /etc/ntp.conf > /dev/null
driftfile /var/lib/ntp/ntp.drift
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# Pool de servidores NTP
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Configurações de acesso
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
restrict source notrap nomodify noquery
EOF
    
    log_message "Reiniciando e habilitando serviço NTP."
    sudo systemctl restart ntp
    sudo systemctl enable ntp
    
    # Verificar status do NTP (apenas log)
    log_message "Verificando status do NTP (ntpq -p)."
    ntpq -p >> "$INSTALL_LOG" 2>&1
    sleep 2
    log_message "Configuração do NTP concluída."
    sucesso_msg "$INSTALL_NTP_SUCCESS"
}

# Função para configurar Hostname e Rede com dialog
configurar_hostname() {
    log_message "Iniciando configuração de Hostname e Rede."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_NETWORK" --infobox "$INSTALL_NETWORK_INFO" 5 60
    
    # Obter hostname atual
    CURRENT_HOSTNAME=$(hostname -f)
    # Obter IP atual (tentar encontrar o IP principal)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    log_message "Hostname atual: $CURRENT_HOSTNAME, IP atual: $IP_ADDRESS"
    
    # Perguntar pelo novo hostname
    log_message "Solicitando novo hostname ao usuário."
    HOSTNAME=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_HOSTNAME_PROMPT" 8 50 "$CURRENT_HOSTNAME")
    [ $? -ne 0 ] && { log_message "Usuário cancelou a configuração de hostname."; erro "$MSG_CANCELED"; }
    if [ -z "$HOSTNAME" ]; then
        erro "$INSTALL_HOSTNAME_EMPTY"
    fi
    log_message "Novo hostname inserido: $HOSTNAME"
    
    # Perguntar pelo domínio
    log_message "Solicitando domínio ao usuário."
    DOMAIN=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_DOMAIN_PROMPT" 8 50)
    [ $? -ne 0 ] && { log_message "Usuário cancelou a configuração de domínio."; erro "$MSG_CANCELED"; }
    if [ -z "$DOMAIN" ]; then
        erro "$INSTALL_DOMAIN_EMPTY"
    fi
    # Converter domínio para maiúsculas (padrão Kerberos/AD)
    DOMAIN=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')
    log_message "Domínio inserido: $DOMAIN"

    # Perguntar pelo IP estático
    log_message "Solicitando IP estático ao usuário."
    IP_ADDRESS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_IP_PROMPT" 8 50 "$IP_ADDRESS")
    [ $? -ne 0 ] && { log_message "Usuário cancelou a configuração de IP."; erro "$MSG_CANCELED"; }
    if [ -z "$IP_ADDRESS" ]; then
        erro "$INSTALL_IP_EMPTY"
    fi
    log_message "IP estático inserido: $IP_ADDRESS"
    
    # Validar IP (simples)
    if ! [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        erro "$INSTALL_IP_INVALID"
    fi
    
    # Atualizar /etc/hostname
    log_message "Atualizando /etc/hostname para $HOSTNAME"
    echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
    sudo hostnamectl set-hostname "$HOSTNAME"
    
    # Atualizar /etc/hosts
    log_message "Atualizando /etc/hosts com $IP_ADDRESS $HOSTNAME.$DOMAIN $HOSTNAME"
    sudo sed -i "/^127.0.1.1/d" /etc/hosts
    # Remover entradas antigas para o IP atual ou hostname
    sudo sed -i "/$IP_ADDRESS/d" /etc/hosts
    sudo sed -i "/$HOSTNAME/d" /etc/hosts
    echo "$IP_ADDRESS    $HOSTNAME.$DOMAIN    $HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
    
    # Configurar IP estático (simplificado - assume interface eth0 ou similar)
    # ATENÇÃO: Isso é uma simplificação e pode não funcionar em todas as configurações de rede.
    INTERFACE=$(ip route | grep default | sed -e "s/^.*dev //" -e "s/ .*//" | head -n 1)
    if [ -z "$INTERFACE" ]; then
        log_message "AVISO: Não foi possível detectar a interface de rede principal. Usando 'eth0' como padrão."
        aviso "Não foi possível detectar a interface de rede principal. A configuração de IP estático pode falhar.\n\nCould not detect the main network interface. Static IP configuration might fail."
        INTERFACE="eth0" # Suposição padrão
    fi
    log_message "Interface de rede detectada/padrão: $INTERFACE"
    
    # Obter gateway e DNS (se possível)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    DNS_SERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    log_message "Gateway detectado: $GATEWAY, DNS detectados: $DNS_SERVERS"
    
    log_message "Solicitando gateway ao usuário."
    GATEWAY=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_GATEWAY_PROMPT" 8 50 "$GATEWAY")
    [ $? -ne 0 ] && { log_message "Usuário cancelou a configuração de gateway."; erro "$MSG_CANCELED"; }
    log_message "Gateway inserido: $GATEWAY"

    log_message "Solicitando servidores DNS ao usuário."
    DNS_SERVERS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_DNS_PROMPT" 8 50 "$DNS_SERVERS")
    [ $? -ne 0 ] && { log_message "Usuário cancelou a configuração de DNS."; erro "$MSG_CANCELED"; }
    log_message "Servidores DNS inseridos: $DNS_SERVERS"

    # Exemplo de configuração para /etc/network/interfaces (Debian 10/11 com ifupdown)
    # Se usar netplan (Debian 11/12), a abordagem seria diferente.
    if [ -d /etc/network/interfaces.d ]; then
        log_message "Configurando IP estático via /etc/network/interfaces para $INTERFACE."
        # Assume ifupdown
        cat << EOF | sudo tee /etc/network/interfaces > /dev/null
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0 # Assumindo /24, ajuste se necessário
    gateway $GATEWAY
    dns-nameservers $DNS_SERVERS
EOF
        # Reiniciar rede
        log_message "Reiniciando serviço networking."
        if ! sudo systemctl restart networking; then
            log_message "AVISO: Falha ao reiniciar o serviço networking. A rede pode precisar ser reconfigurada manualmente."
            aviso "Falha ao reiniciar o serviço networking. A rede pode precisar ser reconfigurada manualmente.\n\nFailed to restart the networking service. The network might need manual reconfiguration."
        fi
    elif [ -d /etc/netplan ]; then
         log_message "Configurando IP estático via netplan para $INTERFACE."
         # Assume netplan
         NETMASK="24" # Assumindo /24, ajuste se necessário
         DNS_SERVERS_YAML=$(echo $DNS_SERVERS | sed 's/ /, /g')
         cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$IP_ADDRESS/$NETMASK]
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS_YAML]
EOF
         log_message "Aplicando configuração netplan."
         if ! sudo netplan apply; then
             log_message "AVISO: Falha ao aplicar a configuração netplan. A rede pode precisar ser reconfigurada manualmente."
             aviso "Falha ao aplicar a configuração netplan. A rede pode precisar ser reconfigurada manualmente.\n\nFailed to apply netplan configuration. The network might need manual reconfiguration."
         fi
    else
        log_message "AVISO: Sistema de configuração de rede não suportado automaticamente (nem ifupdown nem netplan detectados)."
        aviso "Configuração de rede não suportada automaticamente. Configure o IP estático manualmente.\n\nNetwork configuration not automatically supported. Please configure the static IP manually."
    fi
    
    log_message "Configuração de Hostname e Rede concluída."
    sucesso_msg "$INSTALL_NETWORK_SUCCESS"
}

# Função para configurar DNS para AD DC
configurar_dns_ad() {
    log_message "Iniciando configuração de DNS para AD DC."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_DNS" --infobox "$INSTALL_DNS_AD_INFO" 5 60
    
    # Configurar /etc/resolv.conf para usar o próprio servidor como DNS primário
    # Tornar o arquivo imutável para evitar sobrescritas pelo DHCP
    log_message "Configurando /etc/resolv.conf para usar 127.0.0.1 e tornando imutável."
    sudo chattr -i /etc/resolv.conf 2>/dev/null
    cat << EOF | sudo tee /etc/resolv.conf > /dev/null
domain $DOMAIN
search $DOMAIN
nameserver 127.0.0.1 # Usar o próprio servidor
# Adicionar outros DNS como fallback se necessário
# nameserver 8.8.8.8
EOF
    sudo chattr +i /etc/resolv.conf
    
    log_message "Configuração de DNS para AD DC concluída."
    sucesso_msg "$INSTALL_DNS_AD_SUCCESS"
}

# Função para provisionar o Samba como AD DC
provisionar_ad() {
    log_message "Iniciando provisionamento do Samba como AD DC."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_PROVISION" --infobox "$INSTALL_PROVISION_INFO" 5 60
    
    # Obter senha do administrador do domínio
    local ADMIN_PASS ADMIN_PASS_CONFIRM
    while true; do
        log_message "Solicitando senha do Administrador do domínio."
        ADMIN_PASS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$INSTALL_ADMIN_PASS_PROMPT" 8 60)
        [ $? -ne 0 ] && { log_message "Usuário cancelou a inserção da senha."; erro "$MSG_CANCELED"; }
        ADMIN_PASS_CONFIRM=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$INSTALL_ADMIN_PASS_CONFIRM" 8 60)
        [ $? -ne 0 ] && { log_message "Usuário cancelou a confirmação da senha."; erro "$MSG_CANCELED"; }
        
        if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ] || [ -z "$ADMIN_PASS" ]; then
            log_message "Erro: Senhas não conferem ou estão vazias."
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$INSTALL_PASS_MISMATCH" 5 50
        else
            log_message "Senha do Administrador definida."
            break
        fi
    done
    
    # Remover configuração antiga se existir
    log_message "Removendo /etc/samba/smb.conf antigo, se existir."
    sudo rm -f /etc/samba/smb.conf
    
    # Executar provisionamento
    local provision_log="/tmp/samba_provision.log"
    rm -f "$provision_log"
    log_message "Executando samba-tool domain provision... Realm: $DOMAIN, Domain: $(echo $DOMAIN | cut -d. -f1 | tr '[:upper:]' '[:lower:]'), Backend DNS: SAMBA_INTERNAL"
    # Usar --use-rfc2307 para compatibilidade com clientes Linux/Unix
    # Usar --dns-backend=SAMBA_INTERNAL para o DNS interno do Samba
    # Usar --option="interfaces=lo $INTERFACE" e "bind interfaces only=yes" para segurança
    if ! sudo samba-tool domain provision --use-rfc2307 --realm="$DOMAIN" --domain="$(echo $DOMAIN | cut -d. -f1 | tr '[:upper:]' '[:lower:]')" \
        --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass="$ADMIN_PASS" --option="interfaces=lo $INTERFACE" \
        --option="bind interfaces only=yes" >> "$provision_log" 2>&1; then
        log_message "ERRO: Falha no provisionamento do domínio Samba. Ver log '$provision_log'."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox "$provision_log" 20 70
        erro "$INSTALL_PROVISION_FAIL"
    fi
    
    # Copiar configuração do Kerberos
    log_message "Copiando /var/lib/samba/private/krb5.conf para /etc/."
    sudo cp /var/lib/samba/private/krb5.conf /etc/
    
    log_message "Provisionamento do domínio AD concluído com sucesso."
    sucesso_msg "$INSTALL_PROVISION_SUCCESS"
}

# Função para configurar o serviço Samba AD DC
configurar_servico_ad() {
    log_message "Iniciando configuração do serviço samba-ad-dc."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_SERVICE" --infobox "$INSTALL_SERVICE_AD_INFO" 5 60
    
    # Desmascarar, habilitar e iniciar o serviço samba-ad-dc
    log_message "Desmascarando, habilitando e iniciando o serviço samba-ad-dc."
    sudo systemctl unmask samba-ad-dc >> "$INSTALL_LOG" 2>&1
    sudo systemctl enable samba-ad-dc >> "$INSTALL_LOG" 2>&1
    sudo systemctl start samba-ad-dc >> "$INSTALL_LOG" 2>&1
    
    # Verificar status
    log_message "Verificando status do serviço samba-ad-dc."
    sleep 5 # Dar tempo para o serviço iniciar
    if ! systemctl is-active --quiet samba-ad-dc; then
        log_message "AVISO: Serviço samba-ad-dc não está ativo após iniciar."
        sudo systemctl status samba-ad-dc --no-pager >> "$INSTALL_LOG"
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox "$INSTALL_LOG" 20 70
        aviso "$INSTALL_SERVICE_AD_WARN"
    else
        log_message "Serviço samba-ad-dc iniciado e ativo."
        sucesso_msg "$INSTALL_SERVICE_AD_SUCCESS"
    fi
}

# Função para testar o AD DC
testar_ad() {
    log_message "Iniciando testes básicos do AD DC."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TEST" --infobox "$INSTALL_TEST_INFO" 5 50
    
    local test_log="/tmp/samba_test.log"
    rm -f "$test_log"
    touch "$test_log"
    local has_errors=0
    
    echo "--- Teste DNS --- (host -t SRV _ldap._tcp.$DOMAIN)" >> "$test_log"
    if ! host -t SRV _ldap._tcp.$DOMAIN >> "$test_log" 2>&1; then
        echo "ERRO: Teste SRV LDAP falhou." >> "$test_log"
        has_errors=1
    fi
    
    echo "--- Teste DNS --- (host -t SRV _kerberos._udp.$DOMAIN)" >> "$test_log"
    if ! host -t SRV _kerberos._udp.$DOMAIN >> "$test_log" 2>&1; then
        echo "ERRO: Teste SRV Kerberos falhou." >> "$test_log"
        has_errors=1
    fi
    
    echo "--- Teste DNS --- (host -t A $HOSTNAME.$DOMAIN)" >> "$test_log"
    if ! host -t A $HOSTNAME.$DOMAIN >> "$test_log" 2>&1; then
        echo "ERRO: Teste registro A falhou." >> "$test_log"
        has_errors=1
    fi
    
    echo "--- Teste Kerberos --- (kinit administrator)" >> "$test_log"
    # Tentar obter ticket Kerberos (requer senha, usar kinit com pipe)
    # Nota: Isso pode ser menos seguro. Uma alternativa é pedir a senha novamente.
    # Por simplicidade, vamos apenas verificar se klist funciona após o kinit (se bem sucedido)
    # echo "$ADMIN_PASS" | kinit administrator@$DOMAIN >> "$test_log" 2>&1
    # if [ $? -ne 0 ]; then
    #     echo "ERRO: Falha ao obter ticket Kerberos (kinit)." >> "$test_log"
    #     has_errors=1
    # else
    #     echo "--- Teste Kerberos --- (klist)" >> "$test_log"
    #     klist >> "$test_log" 2>&1
    #     kdestroy # Destruir ticket após teste
    # fi
    # Simplificação: Apenas verificar se o comando kinit existe e pode ser chamado
    if command -v kinit &> /dev/null; then
         echo "INFO: Comando kinit encontrado. Teste manual recomendado: kinit administrator@$DOMAIN" >> "$test_log"
    else
         echo "AVISO: Comando kinit não encontrado. Não foi possível testar Kerberos automaticamente." >> "$test_log"
    fi

    echo "--- Teste Conexão Samba --- (smbclient -L localhost -U%)" >> "$test_log"
    if ! smbclient -L localhost -U% >> "$test_log" 2>&1; then
        echo "ERRO: Falha ao listar compartilhamentos locais (smbclient)." >> "$test_log"
        has_errors=1
    fi
    
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TEST_RESULTS" --textbox "$test_log" 20 70
    
    if [ $has_errors -eq 1 ]; then
        log_message "AVISO: Testes do AD DC encontraram erros. Ver log '$test_log'."
        aviso "$INSTALL_TEST_FAIL"
    else
        log_message "Testes básicos do AD DC concluídos com sucesso."
        sucesso_msg "$INSTALL_TEST_SUCCESS"
    fi
}

# --- Funções para Outros Modos (Membro, Servidor de Arquivos) --- 
# (Implementação simplificada ou placeholders)

configurar_como_membro() {
    log_message "Iniciando configuração como Membro de Domínio."
    # 1. Obter nome do domínio, usuário e senha com permissão para join
    REALM=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$JOIN_REALM_PROMPT" 8 50)
    [ $? -ne 0 ] && { log_message "Usuário cancelou config membro."; erro "$MSG_CANCELED"; }
    REALM=$(echo "$REALM" | tr '[:lower:]' '[:upper:]')

    JOIN_USER=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$JOIN_USER_PROMPT" 8 50 "administrator")
    [ $? -ne 0 ] && { log_message "Usuário cancelou config membro."; erro "$MSG_CANCELED"; }

    JOIN_PASS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$JOIN_PASS_PROMPT ($JOIN_USER)" 8 60)
    [ $? -ne 0 ] && { log_message "Usuário cancelou config membro."; erro "$MSG_CANCELED"; }

    # 2. Configurar /etc/krb5.conf (pode ser obtido do DC ou configurado manualmente)
    log_message "Configurando /etc/krb5.conf para o realm $REALM."
    cat << EOF | sudo tee /etc/krb5.conf > /dev/null
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF

    # 3. Configurar /etc/samba/smb.conf básico
    log_message "Configurando /etc/samba/smb.conf para membro de domínio."
    WORKGROUP=$(echo $REALM | cut -d. -f1)
    cat << EOF | sudo tee /etc/samba/smb.conf > /dev/null
[global]
   workgroup = $WORKGROUP
   security = ads
   realm = $REALM

   # Configurações Winbind
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999
   idmap config $WORKGROUP : backend = rid
   idmap config $WORKGROUP : range = 10000-999999

   winbind nss info = rfc2307
   winbind trusted domains only = no
   winbind use default domain = yes
   winbind enum users = yes
   winbind enum groups = yes
   winbind refresh tickets = yes

   # Desabilitar impressão se não for necessária
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

   # Template shell e homedir para usuários do AD
   template shell = /bin/bash
   template homedir = /home/%U
EOF

    # 4. Configurar /etc/resolv.conf para apontar para o DNS do AD
    log_message "Configurando /etc/resolv.conf para usar DNS do AD (necessário manualmente ou via DHCP)."
    aviso "Certifique-se que /etc/resolv.conf aponta para o(s) DNS do domínio $REALM.\n\nEnsure /etc/resolv.conf points to the DNS server(s) of the $REALM domain."
    # Exemplo: sudo echo "nameserver <IP_DO_DNS_AD>" > /etc/resolv.conf

    # 5. Ingressar no domínio
    local join_log="/tmp/samba_join.log"
    rm -f "$join_log"
    log_message "Tentando ingressar no domínio $REALM como usuário $JOIN_USER."
    echo "$JOIN_PASS" | sudo net ads join -U "$JOIN_USER"%"$JOIN_PASS" >> "$join_log" 2>&1
    # Alternativa interativa: sudo net ads join -U "$JOIN_USER"

    if grep -q -i "Joined" "$join_log"; then
        log_message "Ingresso no domínio $REALM realizado com sucesso."
        # 6. Configurar PAM e NSS
        log_message "Configurando PAM e NSS para autenticação via Winbind."
        sudo pam-auth-update --enable winbind --force
        sudo sed -i 's/passwd:         compat/passwd:         compat winbind/g' /etc/nsswitch.conf
        sudo sed -i 's/group:          compat/group:          compat winbind/g' /etc/nsswitch.conf
        sudo sed -i 's/shadow:         compat/shadow:         compat winbind/g' /etc/nsswitch.conf

        # 7. Iniciar e habilitar serviços
        log_message "Iniciando e habilitando serviços smbd, nmbd, winbind."
        sudo systemctl restart smbd nmbd winbind
        sudo systemctl enable smbd nmbd winbind

        # 8. Testar
        log_message "Testando configuração de membro (wbinfo -u, wbinfo -g)."
        sleep 5
        wbinfo -u >> "$join_log"
        wbinfo -g >> "$join_log"
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$JOIN_TEST_RESULTS" --textbox "$join_log" 20 70
        sucesso_msg "$JOIN_SUCCESS"
    else
        log_message "ERRO: Falha ao ingressar no domínio $REALM. Ver log '$join_log'."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox "$join_log" 20 70
        erro "$JOIN_FAIL"
    fi
}

configurar_como_servidor_arquivos() {
    log_message "Iniciando configuração como Servidor de Arquivos Standalone."
    # 1. Garantir que smbd e nmbd estão instalados (já feito em instalar_samba_pacote)
    # 2. Configurar /etc/samba/smb.conf básico
    log_message "Configurando /etc/samba/smb.conf para servidor de arquivos standalone."
    WORKGROUP=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$FILESERVER_WORKGROUP_PROMPT" 8 50 "WORKGROUP")
    [ $? -ne 0 ] && { log_message "Usuário cancelou config servidor arquivos."; erro "$MSG_CANCELED"; }

    cat << EOF | sudo tee /etc/samba/smb.conf > /dev/null
[global]
   workgroup = $WORKGROUP
   server string = %h Samba Server
   security = user
   map to guest = Bad User
   dns proxy = no

   # Logging (opcional, pode ser mais detalhado)
   log file = /var/log/samba/log.%m
   max log size = 1000

   # Desempenho (ajustes básicos)
   socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
   use sendfile = yes

   # Desabilitar impressão se não for necessária
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

#============================ Share Definitions ==============================

# Exemplo de compartilhamento público (sem senha)
#[Public]
#   path = /srv/samba/public
#   public = yes
#   writable = yes
#   comment = Public Share
#   printable = no
#   guest ok = yes

# Exemplo de compartilhamento privado (requer usuário Samba)
#[Private]
#   path = /srv/samba/private
#   valid users = @sambausers # Grupo de usuários Samba
#   guest ok = no
#   writable = yes
#   comment = Private Share
#   printable = no
#   create mask = 0660
#   directory mask = 0770
EOF

    # 3. Criar diretórios de exemplo (se necessário)
    # sudo mkdir -p /srv/samba/public
    # sudo chmod 777 /srv/samba/public
    # sudo mkdir -p /srv/samba/private
    # sudo chgrp sambausers /srv/samba/private # Assumindo que existe um grupo sambausers
    # sudo chmod 770 /srv/samba/private

    # 4. Iniciar/Reiniciar e habilitar serviços
    log_message "Reiniciando e habilitando serviços smbd e nmbd."
    sudo systemctl restart smbd nmbd
    sudo systemctl enable smbd nmbd

    # 5. Adicionar usuários Samba (requer interação ou script separado)
    log_message "Configuração básica de servidor de arquivos concluída."
    aviso "A configuração básica do servidor de arquivos foi concluída. Você precisará criar usuários Samba (com 'smbpasswd -a <username>') e definir compartilhamentos em /etc/samba/smb.conf.\n\nBasic file server configuration is complete. You will need to create Samba users (with 'smbpasswd -a <username>') and define shares in /etc/samba/smb.conf."
    sucesso_msg "$FILESERVER_SUCCESS"
}

# --- Fluxo Principal ---

main() {
    verificar_root
    verificar_debian

    # Menu de seleção do tipo de instalação
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
           --title "$INSTALL_TYPE_TITLE" \
           --menu "$INSTALL_TYPE_CHOOSE" 15 70 3 \
           "AD_DC" "$INSTALL_TYPE_AD_DC" \
           "MEMBER" "$INSTALL_TYPE_MEMBER" \
           "FILE_SERVER" "$INSTALL_TYPE_FILE_SERVER" 2> $OUTPUT

    exit_status=$?
    INSTALL_TYPE=$(cat $OUTPUT)
    rm -f $OUTPUT

    if [ $exit_status -ne 0 ]; then
        log_message "Usuário cancelou a seleção do tipo de instalação."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
        exit 0
    fi

    log_message "Tipo de instalação selecionado: $INSTALL_TYPE"

    # Etapas comuns
    atualizar_sistema
    instalar_dependencias
    instalar_samba_pacote
    configurar_ntp
    configurar_hostname # Pede HOSTNAME, DOMAIN, IP, GW, DNS

    # Etapas específicas do tipo
    case $INSTALL_TYPE in
        "AD_DC")
            log_message "Executando etapas para AD DC."
            configurar_dns_ad
            provisionar_ad # Pede senha admin
            configurar_servico_ad
            testar_ad
            log_message "Instalação/Configuração como AD DC concluída."
            sucesso_msg "$INSTALL_AD_DC_COMPLETE"
            ;;
        "MEMBER")
            log_message "Executando etapas para Membro de Domínio."
            configurar_como_membro # Pede realm, user, pass
            log_message "Instalação/Configuração como Membro de Domínio concluída."
            # Mensagem de sucesso já é dada dentro da função
            ;;
        "FILE_SERVER")
            log_message "Executando etapas para Servidor de Arquivos Standalone."
            configurar_como_servidor_arquivos # Pede workgroup
            log_message "Instalação/Configuração como Servidor de Arquivos concluída."
            # Mensagem de sucesso/aviso já é dada dentro da função
            ;;
        *)
            # Não deve acontecer com menu
            erro "Tipo de instalação inválido / Invalid installation type: $INSTALL_TYPE"
            ;;
    esac

    log_message "Script instalar_atualizar_samba.sh concluído."
    # Limpeza final
    rm -f $OUTPUT "$INSTALL_LOG" /tmp/samba_*.log /tmp/dependency_install.log 2>/dev/null
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$INSTALL_ALL_COMPLETE" 8 60
}

# Executar função principal
main

exit 0

