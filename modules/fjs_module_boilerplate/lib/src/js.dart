const String source = r'''
({
  greeting: async function(name) {
    return new Promise((resolve, reject) => {
      setTimeout(() => resolve(`Hello ${name}!`), 1000);
    });
  }
})
''';