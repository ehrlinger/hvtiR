* `setup()` no longer stops when `arrow` cannot be installed. It installs
  `arrow` last, on its own, and on a failure warns, names pak's message and
  the saved log, and sets the study up without it. Some servers cannot build
  current `arrow` (C++20, and OpenSSL 3 for its prebuilt library), and no
  older release compiles on R 4.6. A failure installing any other package
  still stops setup.
