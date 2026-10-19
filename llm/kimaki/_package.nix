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

# package.json の bin は string(bin.js 形)と object(./dist/cli.js 形)が混在するため動的に解決する
let
  version = "1.2.0";
  lockfile = ./bun.lock;

  deps = stdenv.mkDerivation {
    pname = "kimaki-deps";
    inherit version lockfile;

    src = fetchurl {
      url = "https://registry.npmjs.org/kimaki/-/kimaki-${version}.tgz";
      hash = "sha256-OJdqTYHHnHTzdTyyi25zrG3KBrLLLteH63J3X8Lc9o8=";
    };

    nativeBuildInputs = [
      bun
      cacert
      jq
    ];

    outputHashMode = "recursive";
    outputHash = "sha256-ayUlomRmqGNZ61V0U8GdHHv7Em5PIX+NsGem3egnJoY=";

    # fixupのpatchShebangsAutoは#!/bin/shをstore bashへ書き換え、updaterが
    # 算出するpristineなbun installツリーとのハッシュ不一致とFODでの
    # store参照検出(parse check)を招く。kimakiはbunランタイムで動かすため
    # シェバング書換は不要。
    dontPatchShebangs = true;

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
    jq
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
    entry=$(jq -r '.bin | if type == "object" then (.kimaki // first(.[])) else . end' $out/lib/package.json)
    chmod +x $out/lib/$entry
    makeWrapper ${bun}/bin/bun $out/bin/kimaki \
      --add-flags "$out/lib/$entry" \
      --prefix PATH : ${bun}/bin
    runHook postInstall
  '';
}
