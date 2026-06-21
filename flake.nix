{
  description = "Static site for georgian-rizz.com";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          src = lib.cleanSource self;
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "georgian-rizz-com";
            version = "0.1.0";
            inherit src;
            dontUnpack = true;

            nativeBuildInputs = with pkgs; [
              python3
              yq-go
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/assets"

              title="$(yq -r '.title' "$src/content/pickup-lines.yaml")"
              subtitle="$(yq -r '.subtitle' "$src/content/pickup-lines.yaml")"
              yq -o=json '.pickup_lines' "$src/content/pickup-lines.yaml" > "$TMPDIR/pickup-lines.json"

              export TITLE="$title"
              export SUBTITLE="$subtitle"
              export PICKUP_LINES_JSON="$TMPDIR/pickup-lines.json"
              export TEMPLATE="$src/site/index.html"
              export OUTPUT_HTML="$out/index.html"

              python3 <<'PY'
              import html
              import json
              import os
              from pathlib import Path

              lines = json.loads(Path(os.environ["PICKUP_LINES_JSON"]).read_text())
              cards = "\n".join(
                  f'        <article class="line-card"><p>{html.escape(line)}</p></article>'
                  for line in lines
              )

              rendered = (
                  Path(os.environ["TEMPLATE"])
                  .read_text()
                  .replace("__TITLE__", html.escape(os.environ["TITLE"]))
                  .replace("__SUBTITLE__", html.escape(os.environ["SUBTITLE"]))
                  .replace("__PICKUP_LINES__", cards)
              )

              Path(os.environ["OUTPUT_HTML"]).write_text(rendered)
              PY

              cp "$src/site/styles.css" "$out/styles.css"
              cp "$src/site/assets/georgian-rizz.webp" "$out/assets/georgian-rizz.webp"

              runHook postInstall
            '';
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
