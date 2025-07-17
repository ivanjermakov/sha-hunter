build:
	nvcc sha-hunter.cu -o sha-hunter -O3 --compiler-options '-fPIC'

run: build
	./sha-hunter
