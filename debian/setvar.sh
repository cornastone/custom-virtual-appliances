#!/usr/bin/bash
####################################################################
# startup script to change network config based on OVF variables   #
#                                                                  #
# based on https://github.com/lamw/custom-virtual-appliances       #
# by William LAM                                                   #
#                                                                  #
# Adapted to systemd and Debian                                    #
# by ucramer                                                       #
# version: 0.03							   #
#                                                                  #
####################################################################

# log file customization

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/var/log/ovf/variables.log 2>&1

IPFILE=/var/log/ovf/ip.info

$(ip link |grep -v lo > $IPFILE)

while read -r line ; do
  IPNAME=$(echo "${line}" |awk -F ': ' '{print $2}' | awk -F ':' '{print $1}')
  if [ $IPNAME != "lo" ]; then
    IFNAME=$(echo "$IPNAME")
  fi
done < <(grep UP $IPFILE)

rm $IPFILE

# Check if this was run already
if [ -e /var/log/ovf/ran_network ]; then
  echo `date +%F" "%T` "Network already configured. Exiting"
  exit
else
  echo `date +%F" "%T` "Configuring the network:"

  if [ -e /etc/systemd/network/*.network ]; then
    NETWORK_FILE=$(ls /etc/systemd/network | grep .network)
  else
    mv /etc/network/interfaces /etc/network/interfaces.save
    systemctl enable systemd-networkd
    systemctl enable networking
    NETWORK_FILE=$(echo $IFNAME".network")
  fi

    HOSTNAME_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.hostname")
    IP_ADDRESS_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ipaddress")
    NETMASK_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.netmask")
    GATEWAY_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.gateway")
    DNS_SERVER_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.dns")
    DNS_DOMAIN_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.domain")

    ##################################
    ### No User Input, assume DHCP ###
    ##################################
    if [ -z "${HOSTNAME_PROPERTY}" ]; then
	echo `date +%F" "%T` "Configuring the network with DHCP:"
        cat > /etc/systemd/network/${NETWORK_FILE}  << __CUSTOMIZE_NETWORK__
[Match]
Name=$IFNAME

[Network]
DHCP=yes
IPv6AcceptRA=no
__CUSTOMIZE_NETWORK__
    #########################
    ### Static IP Address ###
    #########################
    else
        HOSTNAME=$(echo "${HOSTNAME_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        IP_ADDRESS=$(echo "${IP_ADDRESS_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        NETMASK=$(echo "${NETMASK_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        GATEWAY=$(echo "${GATEWAY_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        DNS_SERVER=$(echo "${DNS_SERVER_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        DNS_DOMAIN=$(echo "${DNS_DOMAIN_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
	length=${#NETMASK}
	if [ $length -gt 2 ]; then
	  scalc=$(ipcalc -nb $IP_ADDRESS $NETMASK| grep -i "netmask" )
	  NETMASK=$(echo -n $scalc | tail -c 2)
	  if [[ $(echo -n $NETMASK | cut -c1) == "/" ]]; then
	    NETMASK=$(echo -n $NETMASK | cut -c2)
	  fi
	fi
	echo `date +%F" "%T` "Configuring the network with Static IP:"

        cat > /etc/systemd/network/${NETWORK_FILE} << __CUSTOMIZE_DEBIAN__
[Match]
Name=$IFNAME
[Network]
Address=${IP_ADDRESS}/${NETMASK}
Gateway=${GATEWAY}
DNS=${DNS_SERVER}
Domains=${DNS_DOMAIN}
__CUSTOMIZE_DEBIAN__

	cat > /etc/resolv.conf << __CUSTOMIZE_DNS__
search ${DNS_DOMAIN}
nameserver ${DNS_SERVER}
__CUSTOMIZE_DNS__

    hostnamectl set-hostname ${HOSTNAME}
    systemctl restart systemd-networkd
    touch /var/log/ovf/ran_network
    fi
    echo `date +%F" "%T` "Configuration is done."

fi
