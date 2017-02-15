# Change list for Sailing v0.3:
1. Modify the grammar and rhetoric, make README.md easy to read
2. Default disable auditd.service, firewall.service, irqbalance
3. DMA: change CMA_SIZE from 128M to 368M
4. Improved build script:
	- Add clean option
	- Support release doc download
	- Modify default variable parameters
5.CentOS bug fixed:
        - update mozjs17-17.0.0-12.el7.centos.0.1.linaro1.aarch64.rpm
        - fix bug (ID: 0000630), which is "CentOS show /usr/lib64/sa/sadc: error while loading shared libraries"

# Remained issues:
1. The aarch64 platform not supported
2. Ubuntu distro not supported
