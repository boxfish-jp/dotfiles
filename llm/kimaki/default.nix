{
  stdenv,
  fetchurl,
  bun,
  cacert,
  jq,
  autoPatchelfHook,
  makeWrapper,
  glibc,
}:
let
  version = "0.22.0";
  lockfile = ./bun.lock;

  deps = stdenv.mkDerivation {
    pname = "kimaki-deps";
    inherit version lockfile;

    src = fetchurl {
      url = "https://registry.npmjs.org/kimaki/-/kimaki-${version}.tgz";
      hash = "sha256-oJc8jKxYio0dNDsMdoNbS4Fay8OOpR3rkjt3BGa67TA=";
    };

    nativeBuildInputs = [
      bun
      cacert
      jq
    ];

    outputHashMode = "recursive";
    outputHash = "sha256-GxBu9DAtgszWgWR8ivxbayfMdoJ+ZLaOCDfEOrN/Smg=";

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      jq 'del(.devDependencies)' package.json > .package.json && mv .package.json package.json
      cp "$lockfile" bun.lock
      bun install --frozen-lockfile --production --ignore-scripts --no-progress
      rm -rf node_modules/@parcel/watcher-linux-x64-musl \
             node_modules/@img/sharp-libvips-linuxmusl-x64 \
             node_modules/@img/sharp-linuxmusl-x64
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "kimaki";
  inherit version;
  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    glibc
    stdenv.cc.cc.lib
    bun
  ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r ${deps}/. $out/lib/
    chmod +x $out/lib/bin.js
    makeWrapper ${bun}/bin/bun $out/bin/kimaki \
      --add-flags "$out/lib/bin.js" \
      --prefix PATH : ${bun}/bin
    runHook postInstall
  '';
}
