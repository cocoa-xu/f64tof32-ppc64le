# f64tof32

Pull from DockerHub
```shell
# the bug can be reproduced when
# compiling Erlang/OTP on ppc64le using gcc 
docker pull cocoaxu/f64tof32:gcc-11.2
docker run -it --rm cocoaxu/f64tof32:gcc-11.2

# the test code works as expected when
# compiling Erlang/OTP on ppc64le using clang
docker pull cocoaxu/f64tof32:clang
docker run -it --rm cocoaxu/f64tof32:clang
```

Or, build from source
```shell
# gcc version
docker build . -t f64tof32:gcc-11.2
docker run -it --rm f64tof32:gcc-11.2

# clang version
docker build . -t f64tof32:clang -f Dockerfile.clang
docker run -it --rm f64tof32:clang
```

Or use the [pre-built binary package](https://www.erlang.org/downloads#prebuilt)
```shell
$ docker run -it --rm ppc64le/ubuntu bash
$ apt update && apt install erlang-dev
$ erl
> <<F32:1/little-float-unit:32>> = <<0.1:1/little-float-unit:32>>.
> F32.
```

## Test
```elixir
iex> float64 = 0.1
0.1
iex> <<float64::float-64>>
<<63, 185, 153, 153, 153, 153, 153, 154>>
iex> <<float32::float-32>> = <<float64::float-32>>
<<75, 82, 5, 152>>
iex> <<float32::float-little-32>> = <<float64::float-32>>
<<76, 118, 26, 64>>
iex> float32
2.4134702682495117
iex> <<float32::float-little-32>> = <<float64::float-little-32>>
<<104, 201, 117, 76>>
iex> float32
64431520.0
iex> <<float32::float-little-32>> = <<float64::float-big-32>>
<<67, 141, 200, 208>>
iex> float32
-26917607424.0
iex> <<float32::float-little-32>> = <<float64::float-native-32>>
<<88, 197, 104, 76>>
iex> float32
61019488.0
```

Inserting some good old printf debugging code to `erts/emulator/beam/erl_bits.c`.

```c
Eterm
erts_bs_get_float_2(Process *p, Uint num_bits, unsigned flags, ErlBinMatchBuffer* mb)
{
    Eterm* hp;
    erlfp16 f16;
    float f32;
    double f64;
    byte* fptr;
    FloatDef f;

    CHECK_MATCH_BUFFER(mb);
    for (size_t index = 0; index < mb->size/8; index++) {
        printf("mb->base[%ld]: %d\r\n", index, mb->base[index]);
    }
    
    // static void check_match_buffer(ErlBinMatchBuffer* mb)
    {
        Eterm realbin;
        Uint byteoffs;
        byte* bytes, bitoffs, bitsz;
        ProcBin* pb;
        ERTS_GET_REAL_BIN(mb->orig, realbin, byteoffs, bitoffs, bitsz);
        bytes = binary_bytes(realbin) + byteoffs;
        ERTS_ASSERT(mb->base >= bytes && mb->base <= (bytes + binary_size(mb->orig)));
        pb = (ProcBin *) boxed_val(realbin);
        printf("pb->size: %ld\r\n", pb->size);
        printf("pb->val: %p\r\n", pb->val);
        printf("pb->bytes: %p\r\n", pb->bytes);
        printf("pb->flags: %ld\r\n", pb->flags);
        for (size_t index = 0; index < mb->size/8; index++) {
            printf("pb->bytes[%ld]: %d\r\n", index, pb->bytes[index]);
        }
        if (pb->thing_word == HEADER_PROC_BIN)
            ERTS_ASSERT(pb->flags == 0);
    }

    if (num_bits == 0) {
	printf("num_bits==0\r\n");
	f.fd = 0.0;
	hp = HeapOnlyAlloc(p, FLOAT_SIZE_OBJECT);
	PUT_DOUBLE(f, hp);
	return make_float(hp);
    }
    printf("mb->size: %ld\r\n", mb->size);
    printf("mb->offset: %ld\r\n", mb->offset);
    if (mb->size - mb->offset < num_bits) {	/* Asked for too many bits.  */
	return THE_NON_VALUE;
    }

    printf("num_bits: %ld\r\n", num_bits);
    if (num_bits == 16) {
	fptr = (byte *) &f16;
    } else if (num_bits == 32) {
	fptr = (byte *) &f32;
    } else if (num_bits == 64) {
	fptr = (byte *) &f64;
    } else {
	return THE_NON_VALUE;
    }
    printf("fptr: %p\r\n", fptr);

    if (BIT_IS_MACHINE_ENDIAN(flags)) {
	printf("BIT_IS_MACHINE_ENDIAN\r\n");
	erts_copy_bits(mb->base, mb->offset, 1,
		  fptr, 0, 1,
		  num_bits);
    } else {
	printf("NOT BIT_IS_MACHINE_ENDIAN\r\n");
	erts_copy_bits(mb->base, mb->offset, 1,
		  fptr + NBYTES(num_bits) - 1, 0, -1,
		  num_bits);
    }
    ERTS_FP_CHECK_INIT(p);

    if (num_bits == 16) {
	f.fd = FP16_TO_FP64(f16);
	ERTS_FP_ERROR_THOROUGH(p, f.fd, return THE_NON_VALUE);
	printf("num_bits==16, f.fd: %lf\r\n", f.fd);
    } else if (num_bits == 32) {
	ERTS_FP_ERROR_THOROUGH(p, f32, return THE_NON_VALUE);
	f.fd = f32;
	printf("num_bits==32, f32: %f, f.fd: %lf\r\n", f32, f.fd);
    } else {
#ifdef DOUBLE_MIDDLE_ENDIAN
	FloatDef ftmp;
	ftmp.fd = f64;
	f.fw[0] = ftmp.fw[1];
	f.fw[1] = ftmp.fw[0];
	ERTS_FP_ERROR_THOROUGH(p, f.fd, return THE_NON_VALUE);
#else
	ERTS_FP_ERROR_THOROUGH(p, f64, return THE_NON_VALUE);
	f.fd = f64;
	printf("num_bits==64, f64: %f, f.fd: %lf\r\n", f64, f.fd);
#endif
    }
    mb->offset += num_bits;
    hp = HeapOnlyAlloc(p, FLOAT_SIZE_OBJECT);
    printf("HeapOnlyAlloc: p: %p, FLOAT_SIZE_OBJECT: %ld\r\n", p, FLOAT_SIZE_OBJECT);
    PUT_DOUBLE(f, hp);
    return make_float(hp);
}
```

Test again,
```elixir
iex> float64 = 0.1
0.1
iex> <<float64::float-32>>
<<0, 0, 0, 47>>
iex> <<float64::float-32>>
<<0, 0, 0, 63>>
iex> <<float64::float-32>>
<<0, 0, 0, 79>>
iex> <<float32::float-32>> = <<float64::float-32>>
mb->size: 32
mb->offset: 0
num_bits: 32
fptr: 0x405d95827c
NOT BIT_IS_MACHINE_ENDIAN
num_bits==32, f32: 0.000000, f.fd: 0.000000
HeapOnlyAlloc: p: 0x4000770ad0, FLOAT_SIZE_OBJECT: 2
<<0, 0, 0, 95>>
iex> <<float32::float-64>> = <<float64::float-64>>
mb->size: 64
mb->offset: 0
num_bits: 64
fptr: 0x405d958280
NOT BIT_IS_MACHINE_ENDIAN
num_bits==64, f64: 0.100000, f.fd: 0.100000
HeapOnlyAlloc: p: 0x4000770ad0, FLOAT_SIZE_OBJECT: 2
<<63, 185, 153, 153, 153, 153, 153, 154>>
```

Test in erlang.
```erlang
% works when hard-code the binary
> <<F32_1:1/little-float-unit:32>> = <<205, 204, 204, 61>>.
> F32_1.
0.10000000149011612

% works when int => f32
> <<F32_2:1/little-float-unit:32>> = <<42:1/little-float-unit:32>>.
> F32_2.
42.0

% not working when f64 => f32
% the rhs <<0.1:1/little-float-unit:32>> evals to random data
> <<F32_3:1/little-float-unit:32>> = <<0.1:1/little-float-unit:32>>.
```
