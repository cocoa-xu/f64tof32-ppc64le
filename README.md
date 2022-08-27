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