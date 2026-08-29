{ system ? builtins.currentSystem }:

let
  nixpkgsRevision = "ffbc9f8cbaacfb331b6017d5a5abb21a492c9a38";
  nixpkgsSource = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsRevision}.tar.gz";
    sha256 = "sha256-1Sm77VfZh3mU0F5OqKABNLWxOuDeHIlcFjsXeeiPazs=";
  };
  pkgs = import nixpkgsSource { inherit system; };

  # Sway 1.12 is pinned separately because the Quickshell 0.3.1 lock still
  # contains Sway 1.11. The unwrapped executable is used by the isolated
  # headless test so host wrapper state cannot affect shutdown behavior.
  swayNixpkgsRevision = "9fbb54b33e91ee4ca368e35a78e0613c720600b3";
  swayNixpkgsSource = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${swayNixpkgsRevision}.tar.gz";
    sha256 = "sha256-cV5xEJJK3BvhU8rEd4mC9UsmDi5qscv/kzGPhBRC5WA=";
  };
  swayPkgs = import swayNixpkgsSource { inherit system; };

  # This is the exact Quickshell revision used by the 0.3.1 verification.
  quickshellRevision = "1a4716cde794a59928d9d9fc15f2afc7a95de360";
  quickshellSource = pkgs.fetchFromGitHub {
    owner = "quickshell-mirror";
    repo = "quickshell";
    rev = quickshellRevision;
    hash = "sha256-CLX2Zp5i5BuLbOxNOkwRd9YY84IOrACNxBV79o9/F9Y=";
  };
  quickshell = pkgs.callPackage "${quickshellSource}/default.nix" {
    gitRev = quickshellRevision;
  };

  qtQmlPath = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
  quickshellQmlPath = "${quickshell}/lib/qt-6/qml";
  fontConfig = pkgs.writeText "hydrogen-fonts.conf" ''
    <?xml version="1.0"?>
    <fontconfig>
      <dir>${pkgs.dejavu_fonts}/share/fonts/truetype</dir>
      <cachedir prefix="xdg">fontconfig</cachedir>
    </fontconfig>
  '';
in
pkgs.mkShell {
  packages = with pkgs; [
    bashInteractive
    coreutils
    findutils
    fontconfig
    foot
    gnugrep
    gnused
    mesa
    nodejs_24
    python3
    qt6.qtdeclarative
    quickshell
    swayPkgs.sway-unwrapped
    xterm
    xwayland
  ];

  shellHook = ''
    export HYDROGEN_TEST_ENVIRONMENT=nix-shell
    export HYDROGEN_NIXPKGS_REVISION=${nixpkgsRevision}
    export HYDROGEN_QUICKSHELL_REVISION=${quickshellRevision}
    export HYDROGEN_SWAY_NIXPKGS_REVISION=${swayNixpkgsRevision}
    export FONTCONFIG_FILE=${fontConfig}
    export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
    export __EGL_VENDOR_LIBRARY_DIRS=${pkgs.mesa}/share/glvnd/egl_vendor.d
    export QML_IMPORT_PATH="${quickshellQmlPath}:${qtQmlPath}:$PWD/hydrogen''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
    export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
  '';
}
