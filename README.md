# base122.wasm

A [base-122](http://blog.kevinalbs.com/base122) implementation in [WebAssembly](http://webassembly.org/).

This implemention is written with WebAssembly Text Format for my learning. I do not have practical purpose.


## Requirements

- [WABT](https://github.com/WebAssembly/wabt)


## Build

```console
$ wast2wasm -o base122.wasm base122.wat
```


## Demo

(Run static file server within this directory and open demo.html)

```console
$ python -m SimpleHTTPServer
# open <http://localhost:8000/demo.html>
```
