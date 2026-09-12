# easyTSA 0.3.0

* New `tsa_setup()`: downloads the TSA program from the Copenhagen Trial
  Unit, installs a Java runtime through 'rJavaEnv' when none works, and
  remembers both, so nothing has to be installed by hand. The program is
  still never bundled (its license forbids redistribution).
* New `tsa_remove()` uninstalls the program and the saved configuration.
* `tsa_jar()` and `tsa_engine()` find the installation saved by
  `tsa_setup()`; `tsa_engine()` offers to run it when the program is missing.
* Links to the TSA program now point to <https://ctu.dk/tools> (the old
  address is gone).

# easyTSA 0.2.0

* Breaking: the TSA program is the calculation engine. `tsa_run()` writes
  the `.TSA` file, runs the program headlessly through 'rJava' and returns
  its results. R implementations of RIS, boundaries and futility were
  removed; `tsa_create()` is a deprecated alias.

# easyTSA 0.1.0

* First version: TSA for 'meta' objects, `.TSA` file exchange and
  'ggplot2' plot.
