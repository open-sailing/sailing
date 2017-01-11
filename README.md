Supposedly, you are working on Ubuntu 12.04 or newer version!

Firstly, to download sailing sources with the following commands when there is no repo initialized.

$ mkdir -p ~/bin
$ sudo apt-get update; sudo apt-get upgrade -y; sudo apt-get install -y wget git
$ wget -c http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O ~/bin/repo
$ chmod a+x ~/bin/repo; echo 'export PATH=~/bin:$PATH' >> ~/.bashrc; export PATH=~/bin:$PATH
$ mkdir -p ~/open-sailing; cd ~/open-sailing
$ repo init -u "https://github.com/open-sailing/sailing.git" -b refs/tags/v1.0.6 --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
$ false; while [ $? -ne 0 ]; do repo sync; done

If the repo prompts errors or the version is too old, please execute the following command to fetch newest repo source:
$ wget http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O ~/bin/repo

If the repo had been initialized,  add the following commands before the “repo init …” command above:
$ repo forall -c git reset --hard
$ repo forall -c git clean -dxf

Secondly, you can build the whole project with the default config file as following command:

$sudo ./sailing/build.sh --builddir=./workspace --deploy=iso

To try more different deploy style based on Sailing, please get help information about build.sh as follow:
$./sailing/build.sh -h

If you just want to quickly try it with binaries, please refer to our binary Download Page to get the latest binaries and documentations for each corresponding boards.

Sailing project read access : ftp://sailing:123@117.78.41.188
