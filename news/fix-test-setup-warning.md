* The test that compiler output is never evaluated as cli markup no longer
  warns `object 'hvtir_pwned' not found` when it passes: its cleanup now
  removes the object only if the injection created it.
