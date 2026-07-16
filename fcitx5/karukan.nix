{
  cmake,
  fetchFromGitHub,
  libxkbcommon,
  openssl,
  pkg-config,
  rustPlatform,
  kdePackages,
  fcitx5,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "karukan";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "togatoga";
    repo = "karukan";
    rev = "c1d9d445a8b365e4c9b8f45cc5a18437f2e52a9f";
    hash = "sha256-V/EIMah2wgB7I7GtbP9DHdyLS4K7LLvNL6NjjxzdWR4=";
  };

  cargoHash = "sha256-cf9HmV+9NCP4cuOrpyJcsZYJfn0hFlWhHeMLLDwy+XU=";

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
    libxkbcommon
    pkg-config
    rustPlatform.bindgenHook # cf. https://github.com/NixOS/nixpkgs/issues/52447#issuecomment-1915060425
    fcitx5
  ];

  buildInputs = [
    kdePackages.extra-cmake-modules
    fcitx5
    libxkbcommon
    openssl
  ];

  doCheck = false;

  configurePhase = ''
    pushd karukan-fcitx5/fcitx5-addon
    cmakeConfigurePhase
    popd
  '';

  buildPhase = ''
    runHook preBuild
    pushd karukan-fcitx5/fcitx5-addon
    cmake --build build
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    pushd karukan-fcitx5/fcitx5-addon
    cmake --install build
    popd
    runHook postInstall
  '';
})
