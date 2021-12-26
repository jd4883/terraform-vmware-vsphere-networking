resource "vsphere_distributed_virtual_switch" "dvs" {
  name            = var.distribution_switch.name
  datacenter_id   = var.datacenter_id
  uplinks         = lookup(var.distribution_switch, "uplinks", [for i in range(1, 9) : "uplink${i}"])
  active_uplinks  = lookup(var.distribution_switch, "active_uplinks", ["uplink1", "uplink2"])
  standby_uplinks = lookup(var.distribution_switch, "standby_uplinks", [for i in range(3, 9) : "uplink${i}"])
  max_mtu         = lookup(var.distribution_switch, "mtu", 9000)
  version         = var.distribution_switch.version

  ### technically this section should work but it has only caused me issues and this has to be done manually
  #dynamic "host" {
  #  for_each = var.hosts
  #  content {
  #    host_system_id = host.key
  #    devices        = host.value
  #  }
  #}
  lifecycle { ignore_changes = [host] } # ensures hosts are not forced into DVS if undesired
}

resource "vsphere_distributed_port_group" "pg" {
  count                           = length(var.port_groups)
  name                            = var.port_groups[count.index].name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.dvs.id
  description                     = lookup(var.port_groups[count.index], "description", "")
  vlan_id                         = var.port_groups[count.index].vlan
  lifecycle { ignore_changes = [vlan_id] } # this is important if you change something in the GUI
}

resource "vsphere_vnic" "vMotion" {
  for_each                = var.hosts
  host                    = each.key
  distributed_switch_port = vsphere_distributed_virtual_switch.dvs.id
  distributed_port_group  = vsphere_distributed_port_group.pg[index(var.port_groups.*.name, "vMotion")].id
  ipv4 {
    dhcp = true
  }
  netstack = "vmotion"
}
