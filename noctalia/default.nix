{ inputs, ... }:
{
  # Noctalia v5(ネイティブ実装)の設定。
  #
  # 設定は store の実体(読み取り専用)で ~/.config/noctalia/config.toml に
  # 配置される。GUI からの変更は ~/.local/state/noctalia/settings.toml
  # (state 側)に分離されるので、GUI 操作もそのまま効く。
  #
  # プラグインは community source(既定の git source)の clone に任せる。
  # ここは `[plugins].enabled` の宣言だけ
  flake.homeModules.noctalia =
    { pkgs, ... }:
    {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        enable = true;

        # flake の build ではなく nixpkgs 側を使う(バイナリキャッシュ済み)。
        package = pkgs.noctalia;

        settings = {
          bar.default = {
            background_opacity = 0.93;
            padding = 2.0;
            radius = 12.0;
            margin_edge = 4;
            margin_ends = 4;
            margin_opposite_edge = 4;
            widget_spacing = 6;
            reserve_space = true;
            show_on_workspace_switch = true;

            start = [
              "launcher"
              "clock"
              "sysmon_cpu"
              "sysmon_cpu_temp"
              "sysmon_ram"
              "active_window"
              "media"
            ];
            center = [ "workspaces" ];
            end = [
              "tray"
              "notifications"
              "battery"
              "volume"
              "brightness"
              "control-center"
              "niri_displays"
            ];
          };

          widget = {
            clock = {
              type = "clock";
              format = "{:%H:%M %a, %b %d}";
            };

            sysmon_cpu = {
              type = "sysmon";
              stat = "cpu_usage";
            };
            sysmon_cpu_temp = {
              type = "sysmon";
              stat = "cpu_temp";
            };
            sysmon_ram = {
              type = "sysmon";
              stat = "ram_used";
            };

            active_window = {
              type = "active_window";
              max_length = 145.0;
            };

            media = {
              type = "media";
              max_length = 145.0;
            };

            workspaces = {
              type = "workspaces";
              show_icons = false;
              labels_only_when_occupied = true;
            };

            niri_displays = {
              type = "raycursive/niri-displays:bar";
            };
          };

          plugins = {
            enabled = [ "raycursive/niri-displays" ];
            auto_update = "none";
          };

          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Noctalia";
            templates = {
              enable_builtin_templates = false;
              enable_community_templates = false;
            };
          };

          wallpaper = {
            directory = "/home/laptop/Pictures/Wallpapers";
            fill_color = "#000000";
            fill_mode = "crop";
            transition = [
              "fade"
              "wipe"
              "disc"
              "stripes"
              "honeycomb"
            ];
            transition_duration = 1500.0;
            automation = {
              enabled = false;
              interval_seconds = 300;
            };
          };

          dock = {
            enabled = true;
            auto_hide = true;
            position = "bottom";
            launcher_position = "none";
            background_opacity = 1.0;
            active_monitor_only = true;
          };

          desktop_widgets.enabled = false;

          notification = {
            position = "bottom_right";
            background_opacity = 1.0;
            keep_dismissed_in_history = true;
            history_retention_hours = 0;
          };

          osd = {
            position = "top_right";
            background_opacity = 1.0;
          };

          brightness = {
            enable_ddcutil = true;
            minimum_brightness = 0.0;
          };

          battery.warning_threshold = 20;

          system.monitor = {
            cpu_usage_activity_threshold = 80.0;
            cpu_usage_critical_threshold = 90.0;
            ram_pct_activity_threshold = 80.0;
            ram_pct_critical_threshold = 90.0;
            cpu_temp_activity_threshold = 80.0;
            cpu_temp_critical_threshold = 90.0;
            disk_used_activity_threshold = 80.0;
            disk_used_critical_threshold = 90.0;
            disk_free_activity_threshold = 20.0;
            disk_free_critical_threshold = 10.0;
          };

          calendar.enabled = true;
          control_center.calendar = {
            show_events_card = true;
            show_week_numbers = false;
          };

          location = {
            custom_schedule = true;
            sunrise = "06:30";
            sunset = "18:30";
          };

          nightlight = {
            temperature_day = 6500;
            temperature_night = 4000;
          };

          backdrop = {
            enabled = true;
            blur_intensity = 0.5;
          };

          shell = {
            avatar_path = "/home/laptop/.face";
            setup_wizard_enabled = false;
            telemetry_enabled = false;
            clipboard_auto_paste = "off";
            launcher = {
              auto_paste = "off";
              categories = true;
              sort_by_usage = true;
            };
            session = {
              show_shortcuts = true;
              actions = [
                {
                  action = "lock";
                  command = "";
                  countdown_seconds = 10.0;
                  enabled = true;
                  glyph = "";
                  label = "";
                  shortcut = "1";
                  variant = "default";
                }
                {
                  action = "logout";
                  command = "";
                  countdown_seconds = 10.0;
                  enabled = true;
                  glyph = "";
                  label = "";
                  shortcut = "2";
                  variant = "default";
                }
                {
                  action = "lock_and_suspend";
                  command = "";
                  countdown_seconds = 10.0;
                  enabled = true;
                  glyph = "";
                  label = "";
                  shortcut = "3";
                  variant = "default";
                }
                {
                  action = "reboot";
                  command = "";
                  countdown_seconds = 10.0;
                  enabled = true;
                  glyph = "";
                  label = "";
                  shortcut = "4";
                  variant = "default";
                }
                {
                  action = "shutdown";
                  command = "";
                  countdown_seconds = 10.0;
                  enabled = true;
                  glyph = "";
                  label = "";
                  shortcut = "5";
                  variant = "destructive";
                }
              ];
            };
          };
        };
      };
    };
}
