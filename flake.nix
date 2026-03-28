{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

    in
    {
      packages.x86_64-linux = rec {

        linuxPackages = pkgs.linuxPackages;
        kernel = linuxPackages.kernel;

        rekexec-init = pkgs.writeScriptBin "init" ''
          #!/bin/sh
          mkdir -p /proc
          mount -t proc proc /proc
          mount -t binfmt_misc none /proc/sys/fs/binfmt_misc

          echo ':cpio:M::\x30\x37\x30\x37\x30\x31::/bin/cpio-interpreter:' \
            > /proc/sys/fs/binfmt_misc/register

          find / | grep -v /r | grep -v /proc | cpio -vo -H newc > /r

          chmod +x /r
          exec /r
        '';

        cpio-interpreter = pkgs.writeScriptBin "cpio-interpreter" ''
          #!/bin/sh

          kexec --load /k --initrd $1 --reuse-cmdline
          kexec --exec
        '';

        initramfs-inner = pkgs.runCommand "initramfs-inner" { } ''
          mkdir -p $out
          cp ${rekexec-init}/bin/init $out/init
          chmod +x $out/init
          cp ${kernel}/bzImage $out/k
          mkdir -p $out/bin
          cp -r ${pkgs.pkgsStatic.busybox}/bin/* $out/bin
          cp -r ${pkgs.pkgsStatic.kexec-tools}/bin/* $out/bin
          cp ${cpio-interpreter}/bin/* $out/bin
        '';

        initramfs = pkgs.runCommand "kexec-initramfs" { buildInputs = [ pkgs.cpio ]; } ''
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

        ctf = pkgs.runCommand "ctf" { } ''
          mkdir $out
          cat ${./pre.txt} <(base64 < ${initramfs}/initramfs.cpio) ${./post.txt} > $out/ctf.sh
        '';

      };
    };
}
