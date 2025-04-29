{
  writeShellScriptBin,
  buildEnv,
}: let
  # Some programs look at variable with specific case.
  _PROXY_ENV="http_proxy ftp_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY";

  # Reference: https://wiki.archlinux.org/title/Proxy_server
  proxyOn = writeShellScriptBin "proxyOn" ''
    function _assignProxy() {
       for envar in ${_PROXY_ENV}
       do
          export $envar=$1
       done

       for envar in "no_proxy NO_PROXY"
       do
          export $envar=$2
       done
    }

    function proxyOn() {
      export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"

      if (( $# > 0 )); then
          # Validation.
          valid=$(echo $@ | sed -n 's/\([0-9]\{1,3\}.\?\)\{4\}:\([0-9]\+\)/&/p')
          if [[ $valid != $@ ]]; then
              >&2 echo "Invalid address"
              return 1
          fi

          local proxy=$1

          _assignProxy $proxy $no_proxy
          echo "Proxy environment variable set."

          return 0
      fi

      echo -n "username: "; read username
      if [[ $username != "" ]]; then
          echo -n "password: "
          read -es password
          local pre="$username:$password@"
      fi

      read -e -p "server: " -i "socks5://127.0.0.1" server
      read -e -p "port: " -i "10808" port
      local proxy=$pre$server:$port

      # TODO: Add validation of an address.
      _assignProxy $proxy $no_proxy
      echo "Proxy environment variable set."
    }
  '';

  proxyOff = writeShellScriptBin "proxyOff" ''
    function proxyOff() {
      for envar in ${_PROXY_ENV}
      do
         unset $envar
      done

      echo -e "Proxy environment variable removed."
    }
  '';
in
  # Combine scripts to a single package.
  buildEnv {
    name = "proxy-toggle";
    paths = [proxyOn proxyOff];
  }
