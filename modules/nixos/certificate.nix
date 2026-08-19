{ config, lib, ... }:

{
  security.pki.certificateFiles = [
    ../../certificate/pve-root-ca.pem
  ];
}
