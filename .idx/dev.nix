{ pkgs, ... }:
  {
    packages = with pkgs; [
      nodejs
      python3
      gnumake
      docker
      git
      gnugrep
    ];
    services.docker.enable = true;
}