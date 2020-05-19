# Debian script and service file

> **Note:**
>  
> based of the original [rc.local](/rc.local) file in the root directory of this repository

## Changes done:
  - Add logging to /var/log/ovf
  - use the name of interface for the network file 
    - currently only working if there is only one interface
  - enable systemd.networkd if the VM is still using ifupdown (/etc/network/interfaces file)
  - change NETMASK with ipcalc, if Adminsitrator puts in a full netmask (e.g. 255.255.255.0) instead of CIDR
  - put changes to /etc/resolv.conf
  

The files in this folder:
  - setvar.sh
  - setvar.service
  
## setvar.sh

This file converts the output of `vmtoolsd --cmd "info-get guestinfo.ovfEnv"` into the systemd-networkd settings.

If the VM is not yet running systemd-networkd, it converts the system to systemd-networkd and disables the /etc/network/interfaces file.

This script should be moved to /usr/local/bin/ and made executable:
```
cp setvar.sh /usr/local/bin/
chmod u+x /usr/local/bin/setvar.sh
```
For the logging, create a folder in /var/log for the log files and ran_network file:
```
mkdir -P /var/log/ovf
```

## setvar.service

This file is teh service file for `setvar.sh`. 

Place the file into /usr/lib/systemd/ssytem and link to /etc/systemd/system. Then enable it:
```
cp setvar.service /usr/lib/systemd/system/
cd /etc/systemd/system
ln -s /usr/lib/systemd/system/setvar.service 
systemctl enable setvar.service
```
