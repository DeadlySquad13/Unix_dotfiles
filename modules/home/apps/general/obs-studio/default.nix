{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "obs-studio";
}
  # FIX: Doesn't detect gpu on Arch.
  # With yay it works, though. It also installed these packages alongside
  # maybe they were missing:
  # libdatachannel-0.20.3-2  libjuice-1.4.0-1  libsrtp-1:2.6.0-1  mbedtls-3.5.2-1  qt6-svg-6.7.0-1  rnnoise-1:0.2-1
{
  home.packages = with pkgs; [
    obs-studio
  ];
}
