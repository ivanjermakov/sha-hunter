cuda:
	nvcc --shared src/sha256.cu -o zig-out/libsha256.so -O3 --compiler-options '-fPIC'

build: cuda
	zig build -Doptimize=ReleaseFast

run: build
	./zig-out/bin/sha_hunter
