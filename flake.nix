{
  description = "MCHOSE mouse configuration tool for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          mchose = pkgs.rustPlatform.buildRustPackage {
            pname = "mchose";
            version = "0.0.1";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;

            nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];
            buildInputs = with pkgs; [
              libxkbcommon
              wayland
              libGL
              libx11
              libxcursor
              libxi
              libxrandr
            ];

            cargoBuildFlags = [ "--features" "gui" ];

            postInstall = ''
              wrapProgram $out/bin/mchose-gui \
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [
                  pkgs.libGL
                  pkgs.libxkbcommon
                  pkgs.wayland
                ]}

              install -Dm644 mchose.desktop $out/share/applications/mchose.desktop
              install -Dm644 docs/icon.png $out/share/icons/hicolor/256x256/apps/mchose.png
            '';

            meta = with pkgs.lib; {
              description = "Configure MCHOSE mice on Linux";
              license = licenses.mit;
              platforms = platforms.linux;
            };
          };
        in {
          default = mchose;
          mchose = mchose;
        }
      );

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          mchosePkg = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in {
          options.services.mchose = {
            enable = lib.mkEnableOption "MCHOSE mouse support (package + udev rules)";
          };

          config = lib.mkIf config.services.mchose.enable {
            environment.systemPackages = [ mchosePkg ];

            services.udev.extraRules = ''
              KERNEL=="hidraw*", ATTRS{idVendor}=="5253", MODE="0660", GROUP="input", TAG+="uaccess"
              KERNEL=="hidraw*", ATTRS{idVendor}=="3837", MODE="0660", GROUP="input", TAG+="uaccess"
            '';
          };
        };
    };
}
