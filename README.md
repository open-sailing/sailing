# Documentation

  Welcome to the official documentation for Sailing and the Reference Software Platform . Currently , the sailing software platform includes kernel base on Estuary 4.7.1 , and the file system using Estuary Release CentOS . These documents and instruction sets are written by the Sailing team .

## Contents

- Sailing Platform Installation Guide

 - Get started with the Reference Software Platform

- Sailing Update Guide

 - How to update the Reference Software Platform

- Sailing Release Version Deploy

 - Used to guide the user to use the Release Version

***

## Sailing Platform Installation Guide

### Step 1.1 Create a Sailing Repository

Firstly , to download sailing sources with the following commands when there is no repo initialized .

    $ mkdir -p ~/bin
    $ sudo apt-get update; sudo apt-get upgrade -y; sudo apt-get install -y wget git 
    $ wget -c http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O ~/bin/repo
    $ chmod a+x ~/bin/repo; echo 'export PATH=~/bin:$PATH' >> ~/.bashrc; export PATH=~/bin:$PATH
    $ mkdir -p ~/open-sailing; cd ~/open-sailing

### Step 1.2 Download a Repository

    $ repo init -u "https://github.com/open-sailing/sailing.git" -b refs/tags/<version> 
      --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo

    $ false; while [ $? -ne 0 ]; do repo sync; done

the `<version>` , you can select from "Switch branches/tags" , i.e. v0.1 , v0.2 , as shown in the figure below steps :

![image](https://github.com/open-sailing/sailing/blob/master/screenshots/version_select.png)

Currently , the latest version is  **refs/tags/v0.2** .
You can get the binaries and documents of the latest version from the following link :

    ftp://sailing:123@117.78.41.188/releases/
### Step 1.3 Excute Sailing Compile

Secondly , you can build the whole project with the default config file as following command :

    $ sudo ./sailing/build.sh
The generated file stored in the default path </workspace/binary/arm64> , include the following files :

    Estuary-TE.iso CentOS_ARM4.tar.gz Image deploy-utils.tar.bz2 grub.cfg grubaa64.efi mini-rootfs.cpio.gz
To try more different deploy style based on Sailing, please get help information about build.sh as follow :

    $ ./sailing/build.sh -h

***

## Sailing Update Guide

### Step 2.1 Check repo status 

If you already have development based on Sailing , you can use the following commands to update repo .

Firstly , check the status of repo to ensure clean , execute the following command :

    $ repo status

### Step 2.2 Ensure repo clean

If there are some branches in repo , execute the following command :

    $ repo abandon <branchname> [<project>...]
If the repo prompts errors or the version is too old , please execute the following command to fetch newest repo source :

    $ wget http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O ~/bin/repo

If the repo had been initialized , add the following commands before the " repo init ..." command above :

    $ repo forall -c git reset --hard 
    $ repo forall -c git clean -dxf

### Step 2.3 Update repo to the latest version

you can update repo version with the following command :

    $ repo init -u "https://github.com/open-sailing/sailing.git" -b refs/tags/<new_version> 
      --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo

    $ false; while [ $? -ne 0 ]; do repo sync; done

This step is similar to **Step 1.2** , just the `<new_version>` is the latest verion tag .

## Sailing Release Version Deploy

If you just want to quickly try it with binaries , please refer to our binary **Download Page** to get the latest binaries and documentations for each corresponding version .

Sailing project read access :

    ftp://sailing:123@117.78.41.188

About how to use version, you can refer to the following document :

    《D05_User_Manual_for_Estuary_os.docx》
This document mainly instructs how to boot up and debug D05 board.

    《HUAWEI Rack Server Upgrade Guide (iBMC) 02.doc》
This document describes how to upgrade the iBMC (Intelligent Baseboard Management Controller), BIOS (basic input/output system), and LCD (liquid crystal display) with iBMC WebUI and verify upgrade results of the Rack Server.

    《Taishan 2280 Server Quick Start Guide (V100R001_01).doc》
This document describes how to install the server hardware environment .
