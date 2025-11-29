{
  lib,
  namespace,
  config,
  ...
}: let
  padding = 4;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "yabai";
  }
  {
    services.yabai = {
      enable = true;

      enableScriptingAddition = true;

      config = {
        focus_follows_mouse = "autoraise";
        mouse_follows_focus = "off";

        window_placement = "second_child";
        window_opacity = "off";
        window_opacity_duration = "0.0";
        window_border = "on";
        window_border_placement = "inset";
        window_border_width = 2;
        window_border_radius = 3;
        active_window_border_topmost = "off";
        window_topmost = "on";
        window_shadow = "float";

        active_window_border_color = "0xff5c7e81";
        normal_window_border_color = "0xff505050";
        insert_window_border_color = "0xffd75f5f";
        active_window_opacity = "1.0";
        normal_window_opacity = "1.0";

        split_ratio = "0.50";
        auto_balance = "on";

        mouse_modifier = "alt";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        layout = "bsp";

        # with sidebar.
        # top_padding = 36;
        top_padding = padding;
        bottom_padding = padding;
        left_padding = padding;
        right_padding = padding;
        window_gap = padding;
      };

      extraConfig = /*bash*/''
        # Autostart layout.
        # INFO: Selectors are case sensitive!

        # One-shot rules.
        # * Space 1
        yabai -m rule --apply app='Logseq' space=1
        # Didn't check
        yabai -m rule --apply app='Ferdium' space=1
        # * Space 2
        yabai -m rule --apply app='Vivaldi' space=2
        # * Space 3
        yabai -m rule --apply app='WezTerm' space=3
        yabai -m rule --apply app='wezterm-gui' space=3
        # * Space 4
        yabai -m rule --apply app='Zotero' space=4
        # * Space 5
        yabai -m rule --apply app='Telegram' space=5
        yabai -m rule --apply app='Microsoft Outlook' space=1

        # Rules.
        # * Space 1
        yabai -m rule --add app='Logseq' space=1
        # Didn't check
        yabai -m rule --add app='Ferdium' space=1
        # * Space 2
        yabai -m rule --add app='Vivaldi' space=2
        # * Space 3
        yabai -m rule --add app='WezTerm' space=3
        yabai -m rule --add app='wezterm-gui' space=3
        # * Space 4
        yabai -m rule --add app='Zotero' space=4
        # * Space 5
        yabai -m rule --add app='Telegram' space=5
        yabai -m rule --add app='Microsoft Outlook' space=1
      '';
    };
  }
