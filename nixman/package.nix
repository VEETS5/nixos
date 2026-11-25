{ lib, rustPlatform, makeWrapper, nvd }:
rustPlatform.buildRustPackage {
  pname = "nixman";
  version = "0.1.0";
  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ makeWrapper ];
  # nvd gives a readable package-level diff before every switch.
  postInstall = ''
    wrapProgram $out/bin/nixman --suffix PATH : ${lib.makeBinPath [ nvd ]}
  '';
  meta = {
    description = "TUI for this NixOS flake: packages, flake inputs, rebuilds, git";
    mainProgram = "nixman";
  };
}
