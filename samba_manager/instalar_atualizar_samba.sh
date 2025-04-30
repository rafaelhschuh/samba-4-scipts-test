#!/bin/bash

# Script de Instalação Completa do Samba 4 no Debian com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Este script realiza a instalação e configuração completa do Samba 4 no Debian,
#            utilizando a interface dialog para interação com o usuário e suporte a PT-BR/EN-US.
#            Permite configurar como controlador de domínio Active Directory, servidor de arquivos,
#            ou membro de domínio.

# Diretório dos scripts e locale
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCALE_DIR="$SCRIPT_DIR/locale"

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
OUTPUT="/tmp/samba_install_output.$$"

# Função para exibir mensagens de erro e sair
erro() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$1" 8 50
    rm -f $OUTPUT
    exit 1
}

# Função para exibir mensagens de aviso
aviso() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "$1" 8 50
}

# Função para exibir mensagens de sucesso
sucesso_msg() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$1" 8 50
}

# Função para verificar se o script está sendo executado como root
verificar_root() {
    if [ "$(id -u)" != "0" ]; then
        erro "Este script deve ser executado como root. Use \'sudo $0\'\n\nThis script must be run as root. Use \'sudo $0\'"
    fi
}

# Função para verificar a versão do Debian
verificar_debian() {
    if [ ! -f /etc/debian_version ]; then
        erro "Este script foi projetado para ser executado no Debian. Sistema operacional não suportado.\n\nThis script is designed to run on Debian. Unsupported operating system."
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    echo "[INFO] Versão do Debian detectada / Debian version detected: $DEBIAN_VERSION"
    
    if [ "$DEBIAN_VERSION" -lt 10 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --yesno "Este script foi testado no Debian 10 (Buster) ou superior. Versões mais antigas podem não funcionar corretamente. Deseja continuar?\n\nThis script was tested on Debian 10 (Buster) or later. Older versions may not work correctly. Do you want to continue?" 8 70
        if [ $? -ne 0 ]; then
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            rm -f $OUTPUT
            exit 0
        fi
    fi
}

# Função para atualizar o sistema com dialog
atualizar_sistema() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --infobox "$INSTALL_UPDATING_REPOS" 5 50
    apt-get update > /dev/null 2>&1 || erro "Falha ao atualizar listas de pacotes / Failed to update package lists"
    
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --infobox "$INSTALL_UPDATING_PACKAGES" 5 70
    apt-get upgrade -y > /dev/null 2>&1 || erro "Falha ao atualizar pacotes / Failed to upgrade packages"
    echo "[INFO] Sistema atualizado com sucesso / System updated successfully"
}

# Função para instalar dependências básicas com dialog
instalar_dependencias() {
    DEPENDENCIAS=("dialog" "acl" "attr" "wget" "curl" "net-tools" "dnsutils" \
                  "python3-setproctitle" "python3-dnspython" "python3-markdown" \
                  "python3-crypto" "gdb" "pkg-config" "libjansson-dev")
    
    LOG_FILE="/tmp/dependency_install.log"
    rm -f $LOG_FILE
    touch $LOG_FILE
    
    # Verificar se o DEBIAN_FRONTEND está definido para noninteractive
    export DEBIAN_FRONTEND=noninteractive
    
    # Atualizar lista de pacotes primeiro
    apt-get update > /dev/null 2>&1
    
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
              echo "INFO: $dep já está instalado, pulando." >> $LOG_FILE
          else
              # Instalar o pacote apenas se não estiver instalado
              apt-get install -y --no-install-recommends "$dep" >> $LOG_FILE 2>&1
              if [ $? -ne 0 ]; then
                  echo "ERRO: Falha ao instalar $dep. Verifique o log." >> $LOG_FILE
                  echo "ERROR: Failed to install $dep. Check log." >> $LOG_FILE
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

    # Verificar se houve erros reais no log (ignorando mensagens sobre pacotes já instalados)
    if grep -q "ERRO:" $LOG_FILE || grep -q "ERROR:" $LOG_FILE; then
        # Mostrar o log, mas continuar mesmo com erros
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox $LOG_FILE 20 70
        aviso "Alguns pacotes podem não ter sido instalados corretamente. O script tentará continuar.\n\nSome packages may not have been installed correctly. The script will try to continue."
    else
        sucesso_msg "$INSTALL_DEPENDENCIES_SUCCESS"
    fi
    
    # Restaurar o DEBIAN_FRONTEND
    unset DEBIAN_FRONTEND
    
    # rm -f $LOG_FILE # Opcional: manter o log para depuração
    echo "[INFO] Dependências básicas verificadas/instaladas / Basic dependencies checked/installed."
}

# Função para instalar o Samba 4 como pacote com dialog
instalar_samba_pacote() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_SAMBA" --infobox "$INSTALL_SAMBA_INFO" 5 60
    
    # Definir DEBIAN_FRONTEND para noninteractive para evitar prompts
    export DEBIAN_FRONTEND=noninteractive
    
    # Instalar pacotes Samba com opção --no-install-recommends
    apt-get install -y --no-install-recommends samba samba-common samba-dsdb-modules samba-vfs-modules \
    winbind libpam-winbind libnss-winbind krb5-config krb5-user > /tmp/samba_install.log 2>&1
    
    # Verificar se houve erros na instalação
    if [ $? -ne 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox /tmp/samba_install.log 20 70
        aviso "Alguns componentes do Samba podem não ter sido instalados corretamente. O script tentará continuar.\n\nSome Samba components may not have been installed correctly. The script will try to continue."
    fi
    
    # Restaurar o DEBIAN_FRONTEND
    unset DEBIAN_FRONTEND
    
    # Parar e desabilitar serviços para evitar conflitos
    echo "[INFO] Parando e desabilitando serviços Samba padrão / Stopping and disabling default Samba services..."
    systemctl stop smbd nmbd winbind > /dev/null 2>&1
    systemctl disable smbd nmbd winbind > /dev/null 2>&1
    
    echo "[INFO] $INSTALL_SAMBA_SUCCESS"
}

# Função para configurar o NTP com dialog
configurar_ntp() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_NTP" --infobox "$INSTALL_NTP_INFO" 5 50
    apt-get install -y ntp > /dev/null 2>&1 || erro "Falha ao instalar NTP / Failed to install NTP"
    
    # Configurar NTP para sincronizar com servidores (usar pool.ntp.org para global)
    cat > /etc/ntp.conf << EOF
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
    
    # Reiniciar serviço NTP
    systemctl restart ntp
    systemctl enable ntp
    
    # Verificar status do NTP (apenas log)
    echo "[INFO] Verificando status do NTP / Checking NTP status..."
    ntpq -p
    sleep 2
    echo "[INFO] $INSTALL_NTP_SUCCESS"
}

# Função para configurar Hostname e Rede com dialog
configurar_hostname() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_NETWORK" --infobox "$INSTALL_NETWORK_INFO" 5 60
    
    # Obter hostname atual
    CURRENT_HOSTNAME=$(hostname -f)
    # Obter IP atual (tentar encontrar o IP principal)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    # Perguntar pelo novo hostname
    HOSTNAME=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_HOSTNAME_PROMPT" 8 50 "$CURRENT_HOSTNAME")
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$HOSTNAME" ]; then
        erro "$INSTALL_HOSTNAME_EMPTY"
    fi
    
    # Perguntar pelo domínio
    DOMAIN=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_DOMAIN_PROMPT" 8 50)
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$DOMAIN" ]; then
        erro "$INSTALL_DOMAIN_EMPTY"
    fi
    
    # Perguntar pelo IP estático
    IP_ADDRESS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_IP_PROMPT" 8 50 "$IP_ADDRESS")
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$IP_ADDRESS" ]; then
        erro "$INSTALL_IP_EMPTY"
    fi
    
    # Validar IP (simples)
    if ! [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        erro "$INSTALL_IP_INVALID"
    fi
    
    # Atualizar /etc/hostname
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME"
    
    # Atualizar /etc/hosts
    sed -i "/^127.0.1.1/d" /etc/hosts
    echo "$IP_ADDRESS    $HOSTNAME.$DOMAIN    $HOSTNAME" >> /etc/hosts
    
    # Configurar IP estático (simplificado - assume interface eth0 ou similar)
    # ATENÇÃO: Isso é uma simplificação e pode não funcionar em todas as configurações de rede.
    # Uma abordagem mais robusta usaria ifupdown ou netplan dependendo da versão do Debian.
    INTERFACE=$(ip route | grep default | sed -e "s/^.*dev //" -e "s/ .*//" | head -n 1)
    if [ -z "$INTERFACE" ]; then
        aviso "Não foi possível detectar a interface de rede principal. A configuração de IP estático pode falhar.\n\nCould not detect the main network interface. Static IP configuration might fail."
        INTERFACE="eth0" # Suposição padrão
    fi
    
    # Obter gateway e DNS (se possível)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    DNS_SERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    
    GATEWAY=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_GATEWAY_PROMPT" 8 50 "$GATEWAY")
    DNS_SERVERS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_DNS_PROMPT" 8 50 "$DNS_SERVERS")
    
    # Exemplo de configuração para /etc/network/interfaces (Debian 10/11 com ifupdown)
    # Se usar netplan (Debian 11/12), a abordagem seria diferente.
    if [ -d /etc/network/interfaces.d ]; then
        # Assume ifupdown
        cat > /etc/network/interfaces << EOF
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
        systemctl restart networking
    else
        aviso "Configuração de rede não suportada automaticamente. Configure o IP estático manualmente.\n\nNetwork configuration not automatically supported. Please configure the static IP manually."
    fi
    
    echo "[INFO] $INSTALL_NETWORK_SUCCESS"
}

# Função para configurar DNS para AD DC
configurar_dns_ad() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_DNS" --infobox "$INSTALL_DNS_AD_INFO" 5 60
    
    # Configurar /etc/resolv.conf para usar o próprio servidor como DNS primário
    # Tornar o arquivo imutável para evitar sobrescritas pelo DHCP
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf << EOF
domain $DOMAIN
search $DOMAIN
nameserver 127.0.0.1 # Usar o próprio servidor
# nameserver 8.8.8.8 # Exemplo de DNS secundário externo
EOF
    chattr +i /etc/resolv.conf
    
    echo "[INFO] $INSTALL_DNS_AD_SUCCESS"
}

# Função para provisionar o Samba como AD DC
provisionar_ad() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_PROVISION" --infobox "$INSTALL_PROVISION_INFO" 5 60
    
    # Obter senha do administrador do domínio
    while true; do
        ADMIN_PASS=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$INSTALL_ADMIN_PASS_PROMPT" 8 60)
        [ $? -ne 0 ] && erro "$MSG_CANCELED"
        ADMIN_PASS_CONFIRM=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --passwordbox "$INSTALL_ADMIN_PASS_CONFIRM" 8 60)
        [ $? -ne 0 ] && erro "$MSG_CANCELED"
        
        if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ] || [ -z "$ADMIN_PASS" ]; then
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$INSTALL_PASS_MISMATCH" 5 50
        else
            break
        fi
    done
    
    # Remover configuração antiga se existir
    rm -f /etc/samba/smb.conf
    
    # Executar provisionamento
    # Usar --use-rfc2307 para compatibilidade com clientes Linux/Unix
    # Usar --dns-backend=SAMBA_INTERNAL para o DNS interno do Samba
    samba-tool domain provision --use-rfc2307 --realm=$DOMAIN --domain=$(echo $DOMAIN | cut -d. -f1) \
    --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass="$ADMIN_PASS" --option="interfaces=lo $INTERFACE" \
    --option="bind interfaces only=yes" > /tmp/samba_provision.log 2>&1
    
    if [ $? -ne 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox /tmp/samba_provision.log 20 70
        erro "$INSTALL_PROVISION_FAIL"
    fi
    
    # Copiar configuração do Kerberos
    cp /var/lib/samba/private/krb5.conf /etc/
    
    echo "[INFO] $INSTALL_PROVISION_SUCCESS"
}

# Função para configurar o serviço Samba AD DC
configurar_servico_ad() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_SERVICE" --infobox "$INSTALL_SERVICE_AD_INFO" 5 60
    
    # Desmascarar, habilitar e iniciar o serviço samba-ad-dc
    systemctl unmask samba-ad-dc
    systemctl enable samba-ad-dc
    systemctl start samba-ad-dc
    
    # Verificar status
    sleep 5 # Dar tempo para o serviço iniciar
    if ! systemctl is-active --quiet samba-ad-dc; then
        aviso "$INSTALL_SERVICE_AD_FAIL"
    else
        echo "[INFO] $INSTALL_SERVICE_AD_SUCCESS"
    fi
}

# Função para configurar DNS reverso (opcional)
configurar_dns_reverso_ad() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_DNS_REVERSE" --yesno "$INSTALL_DNS_REVERSE_PROMPT" 7 60
    if [ $? -eq 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --infobox "$INSTALL_DNS_REVERSE_INFO" 5 60
        # Obter a rede (ex: 192.168.1) e o último octeto do IP
        IP_PREFIX=$(echo $IP_ADDRESS | cut -d. -f1-3)
        IP_LAST_OCTET=$(echo $IP_ADDRESS | cut -d. -f4)
        REVERSE_ZONE=$(echo $IP_PREFIX | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
        
        # Obter senha do administrador novamente (ou usar a variável anterior)
        # Para segurança, é melhor pedir novamente ou usar um método mais seguro
        ADMIN_USER="administrator"
        # ADMIN_PASS já definida em provisionar_ad
        
        # Criar zona reversa
        samba-tool dns zonecreate localhost $REVERSE_ZONE -U $ADMIN_USER --password="$ADMIN_PASS" >> /tmp/samba_provision.log 2>&1
        # Adicionar registro PTR
        samba-tool dns add localhost $REVERSE_ZONE $IP_LAST_OCTET PTR $HOSTNAME.$DOMAIN. -U $ADMIN_USER --password="$ADMIN_PASS" >> /tmp/samba_provision.log 2>&1
        
        if [ $? -ne 0 ]; then
            aviso "$INSTALL_DNS_REVERSE_FAIL"
        else
            echo "[INFO] $INSTALL_DNS_REVERSE_SUCCESS"
        fi
    fi
}

# Função para configurar como Servidor de Arquivos Simples
configurar_servidor_arquivos() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_FILE_SERVER" --infobox "$INSTALL_FILE_SERVER_INFO" 5 60
    
    # Obter nome do workgroup
    WORKGROUP=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$INSTALL_WORKGROUP_PROMPT" 8 50 "WORKGROUP")
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$WORKGROUP" ]; then
        erro "$INSTALL_WORKGROUP_EMPTY"
    fi
    
    # Criar configuração básica smb.conf
    cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = $WORKGROUP
   server string = %h Samba Server
   security = user
   map to guest = Bad User
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   # Adicionar configurações de interface se necessário
   # interfaces = lo $INTERFACE
   # bind interfaces only = yes

# Exemplo de compartilhamento simples (requer criação do diretório /srv/samba/share)
# [Public]
#   comment = Public Share
#   path = /srv/samba/share
#   browsable = yes
#   writable = yes
#   guest ok = yes
#   read only = no
#   # Permissões de diretório/arquivo
#   create mask = 0664
#   directory mask = 0775
#   # Forçar usuário/grupo (opcional)
#   # force user = nobody
#   # force group = nogroup
EOF

    # Criar diretório de exemplo (se descomentado acima)
    # mkdir -p /srv/samba/share
    # chown nobody:nogroup /srv/samba/share # Ajuste conforme necessário
    # chmod 775 /srv/samba/share

    # Habilitar e iniciar serviços smbd e nmbd
    systemctl enable smbd nmbd
    systemctl restart smbd nmbd
    
    # Verificar status
    sleep 3
    if ! systemctl is-active --quiet smbd || ! systemctl is-active --quiet nmbd; then
        aviso "$INSTALL_FILE_SERVER_FAIL"
    else
        echo "[INFO] $INSTALL_FILE_SERVER_SUCCESS"
    fi
}

# Função para configurar DNS para Membro de Domínio
configurar_dns_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_DNS" --infobox "$INSTALL_DNS_MEMBER_INFO" 5 60
    
    # Obter IP do DC
    DC_IP=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MEMBER_DC_IP_PROMPT" 8 50)
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$DC_IP" ]; then
        erro "$MEMBER_DC_IP_EMPTY"
    fi
    
    # Configurar /etc/resolv.conf para usar o DC como DNS primário
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf << EOF
domain $JOIN_DOMAIN
search $JOIN_DOMAIN
nameserver $DC_IP # Usar o DC como DNS
# nameserver 8.8.8.8 # Exemplo de DNS secundário externo
EOF
    # Não tornar imutável, pois pode ser gerenciado pelo sistema
    
    echo "[INFO] $INSTALL_DNS_MEMBER_SUCCESS"
}

# Função para configurar smb.conf para Membro de Domínio
configurar_smb_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_SMB_CONF" --infobox "$INSTALL_SMB_CONF_MEMBER_INFO" 5 60
    
    REALM=$(echo $JOIN_DOMAIN | tr '[:lower:]' '[:upper:]')
    
    cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = $JOIN_WORKGROUP
   security = ads
   realm = $REALM
   
   # Configurações de ID mapping para winbind
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999
   idmap config $JOIN_WORKGROUP : backend = rid
   idmap config $JOIN_WORKGROUP : range = 10000-999999
   
   winbind use default domain = yes
   winbind offline logon = false
   winbind nss info = rfc2307
   winbind enum users = yes
   winbind enum groups = yes
   
   # Template para home directories e shell
   template homedir = /home/%U
   template shell = /bin/bash
   
   # Outras configurações
   log file = /var/log/samba/log.%m
   max log size = 1000
   dns proxy = no
   panic action = /usr/share/samba/panic-action %d
   
   # Configurações de interface (se necessário)
   # interfaces = lo $INTERFACE
   # bind interfaces only = yes
EOF

    echo "[INFO] $INSTALL_SMB_CONF_MEMBER_SUCCESS"
}

# Função para configurar Kerberos para Membro de Domínio
configurar_kerberos_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_KERBEROS" --infobox "$INSTALL_KERBEROS_MEMBER_INFO" 5 60
    
    REALM=$(echo $JOIN_DOMAIN | tr '[:lower:]' '[:upper:]')
    DC_HOSTNAME=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MEMBER_DC_HOSTNAME_PROMPT" 8 50)
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$DC_HOSTNAME" ]; then
        erro "$MEMBER_DC_HOSTNAME_EMPTY"
    fi
    
    cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    $REALM = {
        kdc = $DC_HOSTNAME.$JOIN_DOMAIN
        admin_server = $DC_HOSTNAME.$JOIN_DOMAIN
    }

[domain_realm]
    .$JOIN_DOMAIN = $REALM
    $JOIN_DOMAIN = $REALM
EOF

    echo "[INFO] $INSTALL_KERBEROS_MEMBER_SUCCESS"
}

# Função para ingressar no domínio
ingressar_dominio() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_JOIN_DOMAIN" --infobox "$INSTALL_JOIN_DOMAIN_INFO" 5 60
    
    # Obter usuário administrador do domínio
    ADMIN_USER=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MEMBER_ADMIN_USER_PROMPT" 8 50 "administrator")
    [ $? -ne 0 ] && erro "$MSG_CANCELED"
    if [ -z "$ADMIN_USER" ]; then
        erro "$MEMBER_ADMIN_USER_EMPTY"
    fi
    
    # Parar serviços antes de ingressar
    systemctl stop smbd nmbd winbind > /dev/null 2>&1
    
    # Tentar ingressar no domínio
    net ads join -U "$ADMIN_USER" > /tmp/samba_join.log 2>&1
    
    if [ $? -ne 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox /tmp/samba_join.log 20 70
        erro "$INSTALL_JOIN_DOMAIN_FAIL"
    fi
    
    # Habilitar e iniciar serviços
    systemctl enable smbd nmbd winbind
    systemctl start smbd nmbd winbind
    
    echo "[INFO] $INSTALL_JOIN_DOMAIN_SUCCESS"
}

# Função para configurar NSS para Membro de Domínio
configurar_nss_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_NSS" --infobox "$INSTALL_NSS_MEMBER_INFO" 5 60
    
    # Modificar /etc/nsswitch.conf
    sed -i 's/passwd:.*$/passwd:         compat winbind/' /etc/nsswitch.conf
    sed -i 's/group:.*$/group:          compat winbind/' /etc/nsswitch.conf
    sed -i 's/shadow:.*$/shadow:         compat/' /etc/nsswitch.conf
    
    echo "[INFO] $INSTALL_NSS_MEMBER_SUCCESS"
}

# Função para configurar PAM para Membro de Domínio
configurar_pam_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_PAM" --infobox "$INSTALL_PAM_MEMBER_INFO" 5 60
    
    # Usar pam-auth-update para configurar
    pam-auth-update --enable winbind --enable mkhomedir
    
    echo "[INFO] $INSTALL_PAM_MEMBER_SUCCESS"
}

# Função para testar conexão como Membro de Domínio
testar_conexao_member() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TEST" --infobox "$INSTALL_TEST_MEMBER_INFO" 5 60
    
    TEST_OUTPUT=""
    # Verificar ingresso no domínio
    TEST_OUTPUT+="net ads testjoin: $(net ads testjoin)\n\n"
    # Obter informações do domínio
    TEST_OUTPUT+="net ads info: $(net ads info)\n\n"
    # Listar usuários do domínio (pode demorar)
    TEST_OUTPUT+="wbinfo -u (primeiros 10): $(wbinfo -u | head -n 10)\n\n"
    # Listar grupos do domínio (pode demorar)
    TEST_OUTPUT+="wbinfo -g (primeiros 10): $(wbinfo -g | head -n 10)\n\n"
    # Obter informações de um usuário (ex: administrator)
    TEST_OUTPUT+="getent passwd administrator: $(getent passwd administrator)\n"
    
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TEST" --msgbox "$TEST_OUTPUT" 20 70
    
    echo "[INFO] $INSTALL_TEST_MEMBER_SUCCESS"
}

# Função para verificar instalação existente e decidir fluxo
verificar_e_decidir_fluxo() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --infobox "$INSTALL_CHECKING" 5 60
    sleep 1

    if dpkg -l | grep -q "^ii  samba "; then
        # Samba está instalado
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --yesno "$INSTALL_FOUND" 8 70
        if [ $? -eq 0 ]; then
            # Usuário escolheu atualizar
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --infobox "$INSTALL_UPDATING" 5 60
            # Atualizar sistema (opcional, mas bom)
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --yesno "$INSTALL_UPDATE_SYSTEM" 6 60
            [ $? -eq 0 ] && atualizar_sistema
            # Atualizar dependências (verifica e instala se necessário)
            instalar_dependencias
            # Atualizar pacotes Samba
            atualizar_pacotes_samba
            sucesso_msg "Atualização do Samba 4 concluída! / Samba 4 update completed!"
            rm -f $OUTPUT
            exit 0 # Sair após a atualização
        else
            # Usuário cancelou a atualização
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            rm -f $OUTPUT
            exit 0
        fi
    else
        # Samba não está instalado
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --yesno "$INSTALL_NOT_FOUND" 8 70
        if [ $? -eq 0 ]; then
            # Usuário escolheu instalar
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --infobox "$INSTALL_INSTALLING" 5 60
            # Prosseguir com a instalação completa (o fluxo normal do script)
            return 0
        else
            # Usuário cancelou a instalação
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            rm -f $OUTPUT
            exit 0
        fi
    fi
}

# Função para atualizar pacotes Samba
atualizar_pacotes_samba() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_UPDATE_TITLE" --infobox "Atualizando pacotes Samba... / Updating Samba packages..." 5 60
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update > /dev/null 2>&1
    apt-get install --only-upgrade -y samba samba-common samba-dsdb-modules samba-vfs-modules \
    winbind libpam-winbind libnss-winbind krb5-config krb5-user > /tmp/samba_update.log 2>&1
    
    if [ $? -ne 0 ]; then
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --textbox /tmp/samba_update.log 20 70
        aviso "Falha ao atualizar alguns pacotes Samba. Verifique o log.\n\nFailed to update some Samba packages. Check log."
    fi
    unset DEBIAN_FRONTEND
    
    # Reiniciar serviços relevantes se necessário (ex: samba-ad-dc ou smbd/nmbd/winbind)
    # A lógica exata depende do tipo de instalação existente, pode ser complexo determinar
    # Por simplicidade, podemos apenas informar o usuário para reiniciar manualmente ou tentar reiniciar todos
    echo "[INFO] Tentando reiniciar serviços Samba relevantes... / Attempting to restart relevant Samba services..."
    systemctl try-restart samba-ad-dc smbd nmbd winbind > /dev/null 2>&1
    
    echo "[INFO] Atualização dos pacotes Samba concluída / Samba packages update completed."
}


# --- Início da Execução Principal --- #

# Verificar se é root
verificar_root

# Verificar versão do Debian
verificar_debian

# Verificar instalação existente e decidir fluxo (Instalar ou Atualizar)
verificar_e_decidir_fluxo

# Se chegou aqui, significa que é uma instalação nova

# Perguntar sobre atualização do sistema
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TITLE" --yesno "$INSTALL_UPDATE_SYSTEM" 6 60
if [ $? -eq 0 ]; then
    atualizar_sistema
fi

# Instalar dependências
instalar_dependencias

# Instalar Samba
instalar_samba_pacote

# Configurar NTP
configurar_ntp

# Configurar Hostname e Rede
configurar_hostname

# Selecionar tipo de instalação
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$INSTALL_TYPE" --menu "$INSTALL_TYPE_SELECT" 15 60 3 \
    "DC" "$INSTALL_TYPE_DC" \
    "FILE" "$INSTALL_TYPE_FILE" \
    "MEMBER" "$INSTALL_TYPE_MEMBER" 2> $OUTPUT

INSTALL_MODE=$(cat $OUTPUT)
rm -f $OUTPUT

if [ -z "$INSTALL_MODE" ]; then
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
    exit 0
fi

# Executar configuração específica baseada no modo
case $INSTALL_MODE in
    "DC")
        configurar_dns_ad
        provisionar_ad
        configurar_servico_ad
        configurar_dns_reverso_ad # Opcional, mas recomendado
        FINAL_MSG=$(printf "$FINAL_INFO_TEXT" "$HOSTNAME" "$DOMAIN" "$IP_ADDRESS")
        sucesso_msg "$AD_SUCCESS\n\n$FINAL_MSG"
        ;;
    "FILE")
        configurar_servidor_arquivos
        FINAL_MSG=$(printf "$FINAL_INFO_TEXT" "$HOSTNAME" "$DOMAIN" "$IP_ADDRESS")
        sucesso_msg "$FILE_SERVER_SUCCESS\n\n$FINAL_MSG"
        ;;
    "MEMBER")
        # Obter informações do domínio a ingressar
        while true; do
            JOIN_DOMAIN=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MEMBER_DOMAIN" 8 50)
            [ $? -ne 0 ] && erro "$MSG_CANCELED"
            [ -n "$JOIN_DOMAIN" ] && break
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MEMBER_EMPTY_DOMAIN" 5 40
        done
        while true; do
            JOIN_WORKGROUP=$(dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --stdout --inputbox "$MEMBER_WORKGROUP" 8 50)
            [ $? -ne 0 ] && erro "$MSG_CANCELED"
            [ -n "$JOIN_WORKGROUP" ] && break
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$MEMBER_EMPTY_WORKGROUP" 5 40
        done
        export JOIN_DOMAIN
        export JOIN_WORKGROUP
        
        configurar_dns_member
        configurar_smb_member
        configurar_kerberos_member
        ingressar_dominio
        configurar_nss_member
        configurar_pam_member
        testar_conexao_member
        FINAL_MSG=$(printf "$FINAL_INFO_TEXT" "$HOSTNAME" "$JOIN_DOMAIN" "$IP_ADDRESS")
        sucesso_msg "$MEMBER_SUCCESS\n\n$FINAL_MSG"
        ;;
esac

# Limpar arquivo temporário
rm -f $OUTPUT

exit 0

# --- Fim da Execução Principal --- #

