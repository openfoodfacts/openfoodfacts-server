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
        port = 9000;
        manager = "web";
      };
    };
  };
}