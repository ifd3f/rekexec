pkgs:
let
  lib = pkgs.lib;

  reqKernelParams = "console=ttyS0";
  #testKernelParams = "curlingiron.src=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.raw curlingiron.dst=/dev/sda";
  testKernelParams = "curlingiron.src=http://10.0.2.2:8000/result/idiot.img curlingiron.dst=/dev/sda";

  init = pkgs.writeScriptBin "init" (builtins.readFile ./init.sh);
in
rec {
  kernel = pkgs.linuxPackages.kernel;
  firmware = pkgs.symlinkJoin {
    name = "firmware";
    paths = import ./firmware.nix pkgs;
  };

  nixosBaseKernelMods = pkgs.callPackage ./kernelmodules.nix { };

  modulesClosure = pkgs.makeModulesClosure {
    kernel = lib.getOutput "modules" kernel;
    rootModules = [
      "af_packet"
      "ahci"
      "ata_piix"
      "atkbd"
      "bnx2"
      "e1000"
      "e1000e"
      "ehci_hcd"
      "forcedeth"
      "hid_generic"
      "i8042"
      "igb"
      "ixgbe"
      "libata"
      "loop"
      "nls_cp437"
      "nvme"
      "nvme_core"
      "ohci_hcd"
      "overlay"
      "pata_acpi"
      "r8169"
      "scsi_mod"
      "sd_mod"
      #"shpchp"
      "squashfs"
      "sr_mod"
      "tg3"
      "uas"
      "uhci_hcd"
      "usb_storage"
      "usbcore"
      "usbhid"
      "virtio_net"
      "virtio_pci"
      "xhci_hcd"
    ]
    ++ nixosBaseKernelMods;
    firmware = "${firmware}/lib/firmware";
  };

  bin =
    with pkgs;
    symlinkJoin {
      name = "bin";
      paths = [
        busybox
      ];
    };

  sbin =
    with pkgs;
    symlinkJoin {
      name = "sbin";
      paths = [ busybox ];
    };

  initrd =
    with pkgs;
    makeInitrdNG {
      compressor = "zstd";

      contents = [
        {
          source = "${modulesClosure}/lib";
          target = "/lib";
        }
        {
          source = "${bin}/bin";
          target = "/bin";
        }
        {
          source = "${sbin}/sbin";
          target = "/sbin";
        }
        {
          source = "${init}/bin/init";
          target = "/init";
        }
        {
          source = writeScript "dhcpevent.sh" (builtins.readFile ./dhcpevent.sh);
          target = "/etc/dhcpevent.sh";
        }
      ];
    };

  # A script invoking kexec on ./bzImage and ./initrd
  # Usually used through system.build.kexecTree, but exposed here for composability.
  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    if ! kexec -v >/dev/null 2>&1; then
      echo "kexec not found: please install kexec-tools" 2>&1
      exit 1
    fi
    SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    kexec --load ''${SCRIPT_DIR}/bzImage \
      --initrd=''${SCRIPT_DIR}/initrd \
      --command-line "${reqKernelParams} ${testKernelParams}"
    kexec -e
  '';

  # A tree containing initrd, bzImage and a kexec-boot script.
  kexecTree = pkgs.linkFarm "kexec-tree" [
    {
      name = "initrd";
      path = "${initrd}/initrd";
    }
    {
      name = "bzImage";
      path = "${kernel}/bzImage";
    }
    {
      name = "kexec-boot";
      path = kexecScript;
    }
  ];

  runVM =
    with pkgs;
    writeScriptBin "runVM" ''
      #!/bin/sh
      ${qemu}/bin/qemu-system-x86_64 -kernel ${kernel}/bzImage \
        -initrd ${initrd}/initrd -nographic \
        -append "${reqKernelParams} ${testKernelParams}" "$@"
    '';
}
