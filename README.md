# f64tof32

Pull from DockerHub
```shell
docker pull cocoaxu/f64tof32
docker run -it --rm cocoaxu/f64tof32
```

Or, build from source
```shell
docker build . -t f64tof32
docker run -it --rm f64tof32
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
    printf("HeapOnlyAlloc: p: %p, FLOAT_SIZE_OBJECT: %lld\r\n", p, FLOAT_SIZE_OBJECT);
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
