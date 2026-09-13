{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "media.audio";
  name = "pipewire-pulse";
}
{
  # NOTE: `pipewire-pulse` reads its configuration only at startup. After a Home
  # Manager switch run `systemctl --user restart pipewire-pulse`, then restart
  # OBS and the browser so they re-enumerate the virtual devices.
  xdg.configFile."pipewire/pipewire-pulse.conf.d/10-obs-virtual-mic.conf".text = ''
    pulse.cmd = [
      {
        cmd = "load-module"
        args = "module-null-sink sink_name=obs_processed sink_properties=device.description=OBS-Processed"
        flags = [ ]
      }
      {
        cmd = "load-module"
        args = "module-remap-source master=obs_processed.monitor source_name=obs_virtual_mic source_properties=device.description=OBS-Virtual-Microphone"
        flags = [ ]
      }
    ]
  '';
}
