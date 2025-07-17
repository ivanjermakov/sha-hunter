{ pkgs ? import <nixpkgs> {
    config = {
        allowUnfree = true;
    };
} }:

pkgs.mkShell {
    LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
    nativeBuildInputs = with pkgs; [
        cudaPackages.cuda_nvcc
        cudaPackages.cuda_cudart
        cudaPackages.libcurand
        cudaPackages.cuda_cccl
    ];
}
