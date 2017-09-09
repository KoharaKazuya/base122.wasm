/**
 * Encodes raw data into base-122.
 * @param {ArrayBuffer} rawData - The data to be encoded.
 * @returns {Promise<ArrayBuffer>} The base-122 encoded UTF-8 string data as a ArrayBuffer.
 */
function encode(rawData) {
  return coder(rawData, 'encode');
}

/**
 * Decodes base122 string to raw data.
 * @param {ArrayBuffer} rawData - The base-122 encoded UTF-8 string data as a ArrayBuffer.
 * @return {Promise<ArrayBuffer>} The data as a ArrayBuffer.
 */
function decode(rawData) {
  return coder(rawData, 'decode');
}

function coder(rawData, wasmOperation) {
  const byteData = new Uint8Array(rawData);
  const inputLength = byteData.length;
  const outputWorstLength = Math.ceil(inputLength * 8 / 7) + 1;

  // Memory Layout
  // - [4]: input size (i32/signed)
  // - [x]: input bytes
  // - [1]: `0x00` guard data (for simplity to read 7bits)
  // - [4]: output size (i32/signed)
  // - [x]: output bytes
  const pageSize = Math.ceil((inputLength + outputWorstLength + 9) / 65536)
  const mem = new WebAssembly.Memory({ initial: pageSize });
  const importObject = {
    glue: { mem },
  };
  const buf = new Uint8Array(mem.buffer);
  // set input size
  buf[0] = (inputLength      ) & 0xff;
  buf[1] = (inputLength >>  8) & 0xff;
  buf[2] = (inputLength >> 16) & 0xff;
  buf[3] = (inputLength >> 24) & 0xff;
  // set input bytes
  buf.set(byteData, 4);
  // set guard data
  buf[4 + inputLength] = 0;

  return fetchAndInstantiate('base122.wasm', importObject).then(instance => {
    instance.exports[wasmOperation].call(instance.exports, 0);

    const out = new Uint8Array(mem.buffer.slice(inputLength + 5, inputLength + 9));
    // get output size
    let outputLength = 0;
    outputLength = (outputLength << 8) | out[3];
    outputLength = (outputLength << 8) | out[2];
    outputLength = (outputLength << 8) | out[1];
    outputLength = (outputLength << 8) | out[0];
    return mem.buffer.slice(inputLength + 9, inputLength + outputLength + 9);
  });
}

function fetchAndInstantiate(url, importObject) {
  return fetch(url).then(response =>
    response.arrayBuffer()
  ).then(bytes =>
    WebAssembly.instantiate(bytes, importObject)
  ).then(results =>
    results.instance
  );
}
