{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "network";
  name = "proxy-toggle";
}
{
  programs.bash.bashrcExtra = /*bash*/ ''
    # Importing proxy-toggle module functions.
    _PROXY_TOGGLE_FUNC_TO_IMPORT="proxyOn proxyOff"
    for functionName in $_PROXY_TOGGLE_FUNC_TO_IMPORT; do
      [[ -f ${pkgs.ds-omega.proxy-toggle}/bin/$functionName ]] && . ${pkgs.ds-omega.proxy-toggle}/bin/$functionName
    done
  '';

  home.shellAliases =  {
    proxyOnKarimka = /*bash*/"proxyOn socks5://127.0.0.1:10808";
  };
}
