{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

    in
    {
      packages.x86_64-linux = rec {

        kernel = pkgs.linuxPackages.kernel;

        rekexec-init = pkgs.writeScriptBin "init" ''
          #!/bin/sh
          mkdir -p /proc
          mount -t proc proc /proc

          find / | grep -v /r | grep -v /proc | cpio -vo -H newc > /r

          kexec --load /k --initrd /r --reuse-cmdline
          kexec --exec
        '';

        initramfs-inner = pkgs.runCommand "initramfs-inner" {} ''
          mkdir -p $out
          cp ${rekexec-init}/bin/init $out/init
          chmod +x $out/init
          cp ${kernel}/bzImage $out/k
          mkdir -p $out/bin
          cp -r ${pkgs.pkgsStatic.busybox}/bin/* $out/bin
          cp -r ${pkgs.pkgsStatic.kexec-tools}/bin/* $out/bin
        '';

        initramfs = pkgs.runCommand "kexec-initramfs" { buildInputs = [pkgs.cpio];} ''
          mkdir -p $out
          ( cd ${initramfs-inner} && find . | cpio -o -H newc ) > $out/initramfs.cpio
        '';

        run-qemu = pkgs.writeShellScriptBin "run-qemu" ''
          exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
            -kernel ${kernel}/bzImage \
            -initrd ${initramfs}/initramfs.cpio \
            -append "console=ttyS0" \
            -nographic \
            -m 2G \
            -no-reboot
        '';

        ctf = pkgs.runCommand "ctf" {} ''
          mkdir $out
          cat ${./pre.txt} <(base64 < ${initramfs}/initramfs.cpio) ${./post.txt} > $out/ctf.sh
        '';

      };
    };
}
