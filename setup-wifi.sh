#!/bin/bash
# -------------------------------------------------------------------------------------------------
# Script: setup-wifi.sh  | Rev: 2.01 (210207)
# Author: Steve Bashford | Email: steve@worldpossible.org
# Action: Connect only to given target wifi SSID (no doc/wifi in range: run & reboot when in range)
# -------------------------------------------------------------------------------------------------

# Set Vars:
  SSID="$1"            # Wifi SSID
  PSWD="$2"            # Wifi PSWD
  LOGX="wifi.log"      # Install log
  CRED="wifi-creds"    # SSID/PSWD file
  HDIR="/etc/network"  # Install home dir
  SCPT="setup-wifi.sh" # Script name
  SRVF="/etc/systemd/system/wifi-connect"

# Log cleanup:
  if   [ -e "${HDIR}/${LOGX}" ]; then sudo rm "${HDIR}/${LOGX}"; fi

# Pipe to log:
  ptl_f(){ sudo tee -a "${HDIR}/${LOGX}"; }

# User input (SSID/PSWD): -------------------------------------------------------------------------
  set_f(){
    if   [ -z "${INPT}" ]; then
         echo -e "\n  Please enter ${LABL}:\n" | ptl_f
         read INPT

         # Input display (handles no wifi pswd):
         if   [ -z "${INPT}" ]; then
              echo "  Input: NULL"    | ptl_f
         else echo "  Input: ${INPT}" | ptl_f
         fi

         # Confirm input:
         echo -e "\n  ${LABL}: ${INPT} (select '1' to accept, or any other key to redo)\n" | ptl_f
         read CNFM

         # Test/display confirmation (handles no wifi pswd):
         if   [ -z "${CNFM}" ] || [ "${CNFM}" -ne "1" ]; then
              INPT=""; set_f # Redo
         elif [ -z "${INPT}" ]; then
              echo "  ${LABL}: NULL confirmed"    | ptl_f
         else echo "  ${LABL}: ${INPT} confirmed" | ptl_f
         fi

    else echo "  ${LABL}: ${INPT}" | ptl_f
    fi
  }

# Preset user SSID/PSWD input:
  pre_f(){
    LABL="SSID"; INPT="${SSID}"; set_f; if [ ! -z "${INPT}" ]; then SSID="${INPT}"; fi
    LABL="PSWD"; INPT="${PSWD}"; set_f; if [ ! -z "${INPT}" ]; then PSWD="${INPT}"; fi
  }

# Set wifi rules: ---------------------------------------------------------------------------------
  swr_f(){
    RULS="/etc/polkit-1/rules.d/10-wp-eos-wifi-admin-only.rules"

    if   [[ $(sudo ls "${RULS}" 2>/dev/null) ]]; then
    #if   [ -f "${RULS}" ]; then
         echo "  Wifi rules file found" | ptl_f
         AUTH=$(sudo grep AUTH_ADMIN "${RULS}"  | awk -F '.' '{print $3}' | sed 's/;//')
         HNDL=$(sudo grep NOT_HANDLED "${RULS}" | awk -F '.' '{print $3}' | sed 's/;//')
         RLWC=$(sudo cat "${RULS}" | wc -l)

         # Check if file is current:
         if   [ "${AUTH}" == "AUTH_ADMIN" ] && [ "${HNDL}" == "NOT_HANDLED" ] \
              && [ "${RLWC}" -eq 11 ]; then
              echo "  Wifi rules file is current"
         else urf_f
         fi
    else urf_f
    fi
  }

# Pipe to rules file:
  ptr_f(){ sudo tee -a "${RULS}"; }

# Create wifi rules file:
  urf_f(){
    echo -e "  Updating wifi rules file\n"
    echo 'polkit.addRule(function(action, subject) {'                 | sudo tee "${RULS}"
    echo '    // Require admin authentication to configure networks'                       | ptr_f
    echo '    if (action.id == "org.freedesktop.NetworkManager.settings.modify.system" ||' | ptr_f
    echo '        action.id == "org.freedesktop.NetworkManager.settings.modify.own") {'    | ptr_f
    echo '        if (subject.local && subject.active && subject.isInGroup("sudo")) {'     | ptr_f
    echo '            return polkit.Result.YES;'                                           | ptr_f
    echo '        }'                                                                       | ptr_f
    echo '        return polkit.Result.AUTH_ADMIN;'                                        | ptr_f
    echo '    }'                                                                           | ptr_f
    echo '    return polkit.Result.NOT_HANDLED;'                                           | ptr_f
    echo '});'                                                                             | ptr_f
    echo ""
  }

# Enable wifi service: ----------------------------------------------------------------------------
  ews_f(){
    if   [ -e "${SRVF}.service" ] && [[ $(grep "preset" "${SRVF}.service") ]]; then
         echo "  Wifi service file found (current rev)" | ptl_f
    elif [ -e "${SRVF}.service" ]; then
         echo "  Wifi service file found, but not not current rev" | ptl_f
         dis_f   # Disable service
         sudo rm "${SRVF}.service"
         csf_f   # Generate service file
         esf_f   # Enable service file
    else echo "  Wifi service file NOT found" | ptl_f
         csf_f   # Generate service file
         esf_f   # Enable service file
    fi;  tws_f   # Test enabled service
  }

# Disable service:
  dis_f(){
    if   [ $(systemctl is-active nginx) == "active" ]; then
         echo "  Temporarilly disabeling wifi-connect service" | ptl_f
         sudo systemctl stop wifi-connect
    fi
    if   [[ $(sudo systemctl is-enabled wifi-connect) == "enabled" ]]; then
         sudo systemctl disable    wifi-connect
         sudo systemctl daemon-reload
    fi
  }

# Pipe to service file:
  pts_f(){ sudo tee -a "${SRVF}.service"; }

# Generate service file:
  csf_f(){
    echo "  Generating service file" | ptl_f
    echo ""
    echo "[Unit]" | sudo tee "${SRVF}.service"
    echo "Description=WiFi Connect"              | pts_f
    echo ""                                      | pts_f
    echo "[Service]"                             | pts_f
    echo "ExecStart=/etc/network/${SCPT} preset" | pts_f
    echo ""                                      | pts_f
    echo "[Install]"                             | pts_f
    echo "WantedBy=multi-user.target"            | pts_f
    echo ""
    css_f # Copy target srvc script before srvc start
  }

# Copy setup script (where service file will run it later):
  css_f(){
    if   [ ! -e "${HDIR}/${SCPT}" ]; then
         echo "  Copying service script ${SCPT} to dir: ${HDIR}" | ptl_f
         sudo cp "${SCPT}" "${HDIR}"/
    else echo "  Service script ${SCPT} found: ${HDIR}" | ptl_f
    fi
  }

# Enable service file:
  esf_f(){
    echo "  Enabeling wifi-connect service" | ptl_f
    sudo systemctl enable wifi-connect
    sudo systemctl daemon-reload
    sudo systemctl start  wifi-connect
    sudo /etc/init.d/network-manager restart
    sleep 1s
  }

# Test enabled service:
  tws_f(){
    STAT=$(sudo systemctl is-enabled wifi-connect)

    if   [ "${STAT}" == "enabled" ]; then
         echo "  Service wifi service enabled"   | ptl_f
    else echo "  Enabele and start wifi service" | ptl_f
         esf_f
    fi
  }

# Set wifi action: ----------------------------------------------------------------------------
  swa_f(){
    if   [ ! -z "${SSID}" ] && [ "${SSID}" == "preset" ]; then
         get_f # Get SSID/PSWD from file
    elif [ ! -z "${SSID}" ] && [ "${SSID}" == "delete" ]; then
         wdl_f # Delte SSID/PSWD
         wfd_f # Delete wifi connections
         exit 0;
    else pre_f # User sets SSID/PSWD
         echo "  Finalized - SSID: ${SSID} | PSWD: ${PSWD}" | ptl_f
         sudo bash -c "echo ${SSID} ${PSWD} > ${HDIR}/${CRED}"
    fi;  wfd_f # Delete wifi connections
  }

# Pipe final SSID/PSWD to creds file & log:
  pfc_f(){
    echo "  Finalized - SSID: ${SSID} | PSWD: ${PSWD}" | ptl_f
    echo "${SSID} ${PSWD}" | sudo tee "${HDIR}"/"${CRED}"
  }

# Get SSID/PSWD from tmp file:
  get_f(){
    SSID=$(cat "${HDIR}"/"${CRED}" | awk '{print $1}')
    PSWD=$(cat "${HDIR}"/"${CRED}" | awk '{print $2}')

    if   [ -z "${SSID}" ] || [ -z "${PSWD}" ]; then
         echo "  Credentials invalid" | ptl_f
         exit 0;
    else echo "  Cedentials detected" | ptl_f
    fi
  }

# Delete SSID/PSWD file (remove wifi connect on boot):
  wdl_f(){
    if   [ -e "${HDIR}/${CRED}" ]; then
         echo "  Deleting SSID/PSWD file: ${CRED}" | ptl_f
         sudo rm "${HDIR}/${CRED}"
    fi
  }

# Delete all wifi connections:
  wfd_f(){
    NMNG=$(ls /etc/NetworkManager/system-connections | wc -l)
    if   [ "${NMNG}" -gt "0" ]; then
         echo "  Deleting legacy wifi connections"        | ptl_f
         sudo rm /etc/NetworkManager/system-connections/* | ptl_f
         sudo service network-manager restart             | ptl_f
    else echo "  No legacy wifi connections found"        | ptl_f
    fi
  }

# Connect to wifi:
  con_f(){
    sleep 10s
    CNFM=$(sudo nmcli dev wifi | grep " ${SSID} " | awk '{print $1}' | head -n1)
    echo "  Confirm SSID detection: ${CNFM}" | ptl_f

    if   [ ! -z "${CNFM}" ]; then
         echo "  Connecing to SSID: ${SSID}" | ptl_f
         sudo nmcli dev wifi connect "${SSID}" password "${PSWD}" > /dev/null 2>&1
         sleep 2s
         STAT=$(ls /etc/NetworkManager/system-connections/ | grep "${SSID}".nmconnection)

         if   [ ! -z "${STAT}" ]; then
              echo "  SSID connection confirmed: ${SSID}" | ptl_f
              exit 0;
         elif [ -z "${ERRX}" ]; then
              echo "  SSID connection not found, retry"   | ptl_f
              ERRX="1"
              con_f
         else echo "  SSID connection not found: ${SSID}" | ptl_f
              exit 0;
         fi

    else echo "  WiFi connection out of range, or device undocked" | ptl_f
         echo "  SSID ${SSID} to connect when docked and in range" | ptl_f
    fi
  }

# Delete down-rev service file: -------------------------------------------------------------------
  dsf_f(){
    WIFF="/etc/network/wifi-toggle.sh"

    if   [ -e "${WIFF}" ]; then
         echo "  Deleting down-rev service file: ${WIFF}" | ptl_f
         sudo rm "${WIFF}"
    fi
  }

# Start script: -----------------------------------------------------------------------------------
  swr_f # Set wifi rules
  ews_f # Enable wifi service
  swa_f # Set wifi action
  con_f # Connect to wifi
  dsf_f # Delete downrev
