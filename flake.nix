{
  description = "Vito's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    minegrub-theme = {
      url = "github:Lxtharia/minegrub-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    proton-cachyos.url = "github:powerofthe69/proton-cachyos-nix";
  };

  outputs = { self, nixpkgs, home-manager, stylix, nixvim, nixcord, ... }@inputs:
  let
    # Every directory in hosts/ is one machine; hosts/<name>/default.nix holds
    # its hostname, hardware config and machine-only packages.
    mkHost = name: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/${name}
        ./configuration.nix
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";
          home-manager.users.vito = import ./home/home.nix;
          home-manager.sharedModules = [
            nixvim.homeModules.nixvim
            nixcord.homeModules.nixcord
          ];
        }
      ];
    };
  in
  {
    nixosConfigurations = nixpkgs.lib.genAttrs [ "nixpad" "nixtop" ] mkHost;
  };
}
