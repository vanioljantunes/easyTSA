test_that("saved config round-trips and tsa_jar() uses it", {
  d <- withr::local_tempdir()
  withr::local_options(easyTSA.config_dir = file.path(d, "cfg"), easyTSA.jar = NULL)
  withr::local_envvar(TSA_HOME = "")
  jar <- file.path(d, "TSA.jar")
  file.create(jar)
  expect_equal(tsa_jar(), "")
  .tsa_config_write(list(jar = jar, java_home = ""))
  expect_equal(.tsa_config_read()$jar, jar)
  expect_null(.tsa_config_read()$java_home)
  expect_equal(tsa_jar(), normalizePath(jar))
})

test_that("long config paths with spaces survive the round trip", {
  d <- withr::local_tempdir()
  withr::local_options(easyTSA.config_dir = file.path(d, "cfg"), easyTSA.jar = NULL)
  withr::local_envvar(TSA_HOME = "")
  # longer than write.dcf()'s fold width, shorter than Windows MAX_PATH
  deep <- file.path(d, paste(rep("long folder", 4), collapse = " "), "TSA 0.9.5.10 Beta")
  dir.create(deep, recursive = TRUE)
  jar <- file.path(deep, "TSA.jar")
  file.create(jar)
  .tsa_config_write(list(jar = jar, java_home = deep))
  expect_equal(.tsa_config_read()$jar, jar)
  expect_equal(.tsa_config_read()$java_home, deep)
  expect_equal(tsa_jar(), normalizePath(jar))
})

test_that(".tsa_find_jar() handles flat and nested archives", {
  d <- withr::local_tempdir()
  for (sub in c("flat", file.path("nested", "TSA 0.9.5.10 Beta"))) {
    p <- file.path(d, sub)
    dir.create(file.path(p, "lib"), recursive = TRUE)
    file.create(file.path(p, "TSA.jar"))
  }
  expect_equal(basename(.tsa_find_jar(file.path(d, "flat"))), "TSA.jar")
  expect_match(.tsa_find_jar(file.path(d, "nested")), "TSA 0.9.5.10 Beta", fixed = TRUE)
  expect_equal(.tsa_find_jar(withr::local_tempdir()), "")
})

test_that("tsa_setup() needs license consent before downloading", {
  skip_if(interactive())
  d <- withr::local_tempdir()
  withr::local_options(easyTSA.config_dir = file.path(d, "cfg"), easyTSA.jar = NULL)
  withr::local_envvar(TSA_HOME = "")
  expect_error(suppressMessages(tsa_setup(dir = d, java = FALSE)), "accept_license")
  expect_error(suppressMessages(tsa_setup(dir = d, java = FALSE, accept_license = FALSE)),
               "not accepted")
  expect_false(file.exists(.tsa_config_file()))
})

test_that("tsa_remove() deletes the install folder and config", {
  d <- withr::local_tempdir()
  withr::local_options(easyTSA.config_dir = file.path(d, "cfg"))
  inst <- file.path(d, "inst")
  dir.create(inst)
  file.create(file.path(inst, "TSA.jar"))
  .tsa_config_write(list(jar = file.path(inst, "TSA.jar")))
  expect_message(tsa_remove(dir = inst), "Removed")
  expect_false(dir.exists(inst))
  expect_false(file.exists(.tsa_config_file()))
})
