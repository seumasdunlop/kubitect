terraform apply fails on first run because it doesn't read the network address.  It then taints the node so it is recreated and fails again.
Workaround by deleting the tainted status from the tfstate file.

