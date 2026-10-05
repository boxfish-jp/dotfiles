{
  # 現在の niri の出力配置を flake.wrappers.desktop の settings.outputs へ還流するための
  # nix 表記ダンプ。display-settings パネルや `niri msg output` で一時調整 →
  # このコマンドで出力 → nix に貼付 → rebuild が恒久化の手順。
  # 無効出力は off、VRR 有効時は variable-refresh-rate を出す。
  perSystem =
    { pkgs, ... }:
    {
      packages.dump-niri-outputs = pkgs.writeShellScriptBin "dump-niri-outputs" ''
        set -euo pipefail
        ${pkgs.niri}/bin/niri msg --json outputs | ${pkgs.jq}/bin/jq -r '
          def block:
            .key as $name
            | .value as $o
            | "  " + ($name | tojson) + " = " + (
              if $o.logical == null then
                "{ off = _: { }; };"
              else
                ($o.modes[$o.current_mode] // null) as $m
                | "{\n"
                + (if $m then "    mode = \"\($m.width)x\($m.height)@\($m.refresh_rate / 1000)\";\n" else "" end)
                + "    scale = \($o.logical.scale);\n"
                + "    transform = \"\($o.logical.transform | ascii_downcase)\";\n"
                + "    position = _: { props = { x = \($o.logical.x); y = \($o.logical.y); }; };\n"
                + (if $o.vrr_enabled then "    variable-refresh-rate = \"on\";\n" else "" end)
                + "  };"
              end
            );
          "{" + "\n" + (to_entries | map(block) | join("\n")) + "\n}"
        '
      '';
    };
}
