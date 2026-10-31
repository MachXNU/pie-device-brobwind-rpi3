{
  description = "AOSP development environment for Raspberry Pi 3B+";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-old,
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      oldPkgs = import nixpkgs-old {
        inherit system;

        config = {
          permittedInsecurePackages = [
            "python-2.7.18.7"
          ];
        };
      };

      python2Mako = oldPkgs.python2Packages.buildPythonPackage rec {
        pname = "Mako";
        version = "1.1.6";

        src = oldPkgs.fetchPypi {
          inherit pname version;
          sha256 = "sha256-Tp40WkGSSpVCUblbSyjhSjARRbVEkBMy5liQenRktrI=";
        };

        propagatedBuildInputs = [
          oldPkgs.python2Packages.markupsafe
        ];

        doCheck = false;
      };

      androidEnv = pkgs.buildFHSEnv {
        name = "aosp-rpi3";

        targetPkgs =
          pkgs: with oldPkgs; [
            git
            gitRepo
            gnupg
            curl
            wget

            gdb

            gnumake
            gnum4
            gcc
            binutils
            clang
            lld

            openjdk8
            python2
            python2Mako
            perl

            flex
            bison
            gperf
            bc
            ccache

            zip
            unzip
            zlib
            ncurses
            oldPkgs.ncurses5
            readline
            openssl

            libxml2
            libxslt
            rsync

            util-linux
            procps
            which
            file
            gettext

            android-tools
            dtc
            dosfstools
            e2fsprogs
            parted
            gptfdisk
            flex
          ];

        multiPkgs =
          pkgs: with pkgs; [
            zlib
            ncurses
            glib
            stdenv.cc.cc.lib
          ];

        runScript = "bash";

        profile = ''
          export USE_CCACHE=1
          export CCACHE_EXEC=$(command -v ccache)

          export LOCALE_ARCHIVE_2_27=""
          unset LOCALE_ARCHIVE
          export LANG=C
          export LC_ALL=C
          export LOCPATH=/nonexistent

          export ANDROID_BUILD_TOP="$PWD"

          # Writable AOSP Git configuration
          mkdir -p $ANDROID_BUILD_TOP/.nix-state
          export XDG_CONFIG_HOME="$ANDROID_BUILD_TOP/.nix-state/config"
          export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"

          mkdir -p "$XDG_CONFIG_HOME/git"
          touch "$GIT_CONFIG_GLOBAL"

          # Reuse system Git identity
          export GIT_CONFIG_COUNT=2
          export GIT_CONFIG_KEY_0=user.name
          export GIT_CONFIG_VALUE_0="$(git config --file "$HOME/.config/git/config" user.name)"
          export GIT_CONFIG_KEY_1=user.email
          export GIT_CONFIG_VALUE_1="$(git config --file "$HOME/.config/git/config" user.email)"

          # libtinfo fix
          export LD_LIBRARY_PATH="${oldPkgs.ncurses5}/lib:$LD_LIBRARY_PATH"

          # python2 packges fix
          export PYTHONPATH="${python2Mako}/lib/python2.7/site-packages:''${PYTHONPATH:+:$PYTHONPATH}"

          export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

          echo "AOSP Raspberry Pi development environment"
        '';
      };

    in
    {
      devShells.${system}.default = androidEnv.env;
    };
}
