# variables that can be overriden
variable "hostname" { default = "ranch" }
variable "domain" { default = "qwlocal" }
variable "memoryMB" { default = 1024*1 }
variable "cpu" { default = 1 }
variable "pool" { default = "NFSA" }
variable "diskBytes" { default = 42949672960 }

# instance the provider
provider "libvirt" {
  uri = "qemu+ssh://root@virthost.qwlocal/system"
}

# fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "os_image" {
  name = "${var.hostname}-os_image"
  pool = "NFSA"
  source = "https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2"
  format = "qcow2"
}

# Use CloudInit ISO to add ssh-key to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
          name = "${var.hostname}-commoninit.iso"
          pool = "default"
          user_data = data.template_file.user_data.rendered
          network_config = data.template_file.network_config.rendered
}

resource "libvirt_volume" "os_image_resized" {
  name           = "disk"
  base_volume_id = libvirt_volume.os_image.id
  pool           = "default"
  size           = 32212254720
}

# Use CloudInit to add our ssh-key to the instance
# resource "libvirt_cloudinit_disk" "cloudinit_ubuntu_resized" {

#   network_config = data.template_file.network_config.rendered
#   name           = "${var.hostname}-commoninit.iso"
#   pool = "default"
#   user_data = <<EOF
# #cloud-config
# disable_root: 0
# ssh_pwauth: 1
# users:
#   - name: root
#     ssh-authorized-keys:
#       - ${file("id_rsa.pub")}
# growpart:
#   mode: auto
#   devices: ['/']
# EOF
# }


data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    hostname = var.hostname
    fqdn = "${var.hostname}.${var.domain}"
  }
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config_dhcp.cfg")
}


# Create the machine
resource "libvirt_domain" "domain-centos8" {
  name = var.hostname
  memory = var.memoryMB
  vcpu = var.cpu

  disk {
       volume_id = libvirt_volume.os_image_resized.id
  }
  network_interface {
       network_name = "macvtap-net"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
  # IMPORTANT
  # Ubuntu can hang is a isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = "true"
  }
}

terraform { 
  required_version = ">= 0.12"
}

output "ips" {
  # show IP, run 'terraform refresh' if not populated
  value = libvirt_domain.domain-centos8.*.network_interface.0.addresses
}
