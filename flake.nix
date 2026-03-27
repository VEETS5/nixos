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
  };

  outputs = { self, nixpkgs, home-manager, stylix, nixvim, ... }@inputs:
  {
    nixosConfigurations = {

      nixpad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixpad/hardware-configuration.nix
          ./configuration.nix
	  stylix.nixosModules.stylix
	  { networking.hostName = "nixpad"; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.vito = import ./home/home.nix;
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
          }
        ];
      };

      nixtop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixtop/hardware-configuration.nix
          ./configuration.nix
	  stylix.nixosModules.stylix
          { networking.hostName = "nixtop"; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.vito = import ./home/home.nix;
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
          }
        ];
      };

    };
  };
}
