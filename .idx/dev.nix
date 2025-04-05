{ pkgs, ... }:
  {
    channel = "stable-23.11";

    packages = with pkgs; [
      gnumake
      docker
      git
      gnugrep
    ];
    services.docker.enable = true;
    idx.previews = {
      enable = true;
      previews = {
        web = {
          command = [ "make" "reset_owner" "make" "dev" ];
          manager = "web";
        };
      };
  };
}