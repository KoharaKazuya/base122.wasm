(function demo() {
  fetch('example.jpg').then(response =>
    response.arrayBuffer()
  ).then(buffer => {
    console.log(
      '%c original data as a base64 string \n%c' +
      btoa(String.fromCharCode.apply(null, new Uint8Array(buffer))),
      'color: white; background-color: gray',
      'color: black'
    );
    return encode(buffer);
  }).then(buffer => {
    console.log(
      '%c base122 string \n%c' +
      String.fromCharCode.apply(null, new Uint8Array(buffer)),
      'color: white; background-color: gray',
      'color: black'
    );
    return decode(buffer);
  }).then(result => {
    console.log(
      '%c encode-decoded data as a base64 string \n%c' +
      btoa(String.fromCharCode.apply(null, new Uint8Array(result))),
      'color: white; background-color: gray',
      'color: black'
    );
    document.querySelector('#demoImage').src = 'data:image/jpeg;base64,' + btoa(String.fromCharCode.apply(null, new Uint8Array(result)));
  });
})();
