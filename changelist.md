Change list for Sailing v1.0 :

1. Kernel Changelist :
    - Only the specified branch is reserved :
      - master
      - cust-lts4.7.1-d05-3.0b
      - ex-lts4.1.27-est-d03
      - ex-lts4.1.34-est-d03
      - ex-lts4.1.36-est-d05 
     - The mainline version is 4.9.20
     - The performance optimization patch is merged based on 4.9.20
     - Part of 4.7 kernel configuration items are merged on the 4.9.20 kernel configuration

2. Sailing Scripts Changelist :
    - Support Ubuntu OS
    - Modify Sailing-config.xml configuration file , Sailingv1.0 based on estuary v3.0 release
    - Modify default.xml , evolution of version basd on master
    - Add the version number in the specified path : /etc/version
    - Wget evades the NAT aging timeout and sets the timeout time to 2min
    - The distro replaces only module, retaining the relevant applications such as armor
    - Synchronize the estuary, reuse the estuary deployment scripts, and fix bugs
    - Patches are updated under the patches directory
    - The patch directory adds CentOS &ubuntu openssl performance enhancement patches
    - Sailing adds the post_insall.sh script to install the openssl after the system startup
    - Add the kernel compilation script, and you can run the compilation kernel separately on the D05 board or x86
      - For specific commands, see. / scripts/built-kernel.sh -h

3. BIOS Changelist :
    - PCIe related problem repair
    - Build chain ES3000 card repeat
    - The version number was upgraded from 1.17 to 1.18
    - ACPI support for dynamically monitoring SFP light modules
    - The I2C rate is changed from 100K to 400K when 2P is initialized
    - Change the BIOS default Settings:  Die Interleaving Disable and ECC Support Enable

