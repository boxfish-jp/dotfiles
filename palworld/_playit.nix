{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "playit";
  version = "1.0.10";

  srcDaemon = fetchurl {
    url = "https://github.com/playit-cloud/playit-agent/releases/download/v${version}/playit-linux-amd64";
    hash = "sha256-LffZ8QInqzErGtNBhT206KgkPfXPzbrlhxOkJxcRwzk=";
  };

  srcCli = fetchurl {
    url = "https://github.com/playit-cloud/playit-agent/releases/download/v${version}/playit-cli-linux-amd64";
    hash = "sha256-b9VNFHrh0yMrIsHB9Ko9E88W2InoQMotP5C09QoucwE=";
  };

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $srcDaemon $out/bin/playit
    install -Dm755 $srcCli $out/bin/playit-cli
    runHook postInstall
  '';

  meta = {
    description = "playit.gg global networking agent";
    homepage = "https://playit.gg/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "playit";
  };
}
