PROJECT := rancher

apply:
	echo "This will take about 5 minutes ..."
	terraform apply -auto-approve -var="memoryMB=8192" -var="cpu=2" -var="pool=QWPro" -var="hostname=rancher"

init:
	terraform init

refresh:
	terraform refresh

## recreate terraform resources
rebuild: destroy apply

destroy:
	terraform destroy -auto-approve

## create public/private keypair for ssh
create-keypair:
	@echo "THIDIR=$(THISDIR)"
	ssh-keygen -t rsa -b 4096 -f id_rsa -C $(PROJECT) -N "" -q
ssh:
	ssh root@virthost.qwlocal "virsh reboot rancher"
	echo 'rebooting host . . .'
	sleep 35
	ssh-keygen -f ~/.ssh/known_hosts -R rancher.qwlocal
	sudo systemd-resolve --flush-caches
	sudo systemctl restart dnsmasq.service
	ssh centos@rancher.qwlocal -i id_rsa
metadata:
	terraform refresh && terraform output ips



