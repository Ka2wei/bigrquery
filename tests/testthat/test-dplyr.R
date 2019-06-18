context("dplyr.R")

test_that("historical API continues to work", {
  src <- src_bigquery(bq_test_project(), "basedata")
  x <- dplyr::tbl(src, "mtcars")

  expect_s3_class(x, "tbl")
  expect_true("cyl" %in% dbplyr::op_vars(x))
})

test_that("can work with literal SQL", {
  con_us <- DBI::dbConnect(
    bigquery(),
    project = "bigquery-public-data",
    dataset = "utility_us",
    billing = bq_test_project()
  )
  x <- dplyr::tbl(con_us, dplyr::sql("SELECT * FROM country_code_iso"))

  expect_s3_class(x, "tbl")
  expect_true("fips_code" %in% dbplyr::op_vars(x))
})

test_that("can collect and compute (no dataset)", {
  con <- DBI::dbConnect(bigquery(), project = bq_test_project())
  bq_mtcars <- dplyr::tbl(con, "basedata.mtcars") %>% dplyr::filter(cyl == 4)

  # collect
  x <- dplyr::collect(bq_mtcars)
  expect_equal(dim(x), c(11, 11))

  # compute: temporary
  temp <- dplyr::compute(bq_mtcars)

  # compute: persistent
  name <- paste0("basedata.", random_name())
  temp <- dplyr::compute(bq_mtcars, temporary = FALSE, name = name)
  on.exit(DBI::dbRemoveTable(con, name))

  expect_true(DBI::dbExistsTable(con, name))
})

test_that("can collect and compute (no dataset)", {
  con <- DBI::dbConnect(bigquery(), project = bq_test_project())
  bq_mtcars <- dplyr::tbl(con, "basedata.mtcars") %>% dplyr::filter(cyl == 4)

  # collect
  x <- dplyr::collect(bq_mtcars)
  expect_equal(dim(x), c(11, 11))

  # compute: temporary
  temp <- dplyr::compute(bq_mtcars)

  # compute: persistent
  name <- paste0("basedata.", random_name())
  temp <- dplyr::compute(bq_mtcars, temporary = FALSE, name = name)
  on.exit(DBI::dbRemoveTable(con, name))

  expect_true(DBI::dbExistsTable(con, name))
})

test_that("can collect and compute (with dataset)", {
  con <- DBI::dbConnect(bigquery(),
    project = bq_test_project(),
    dataset = "basedata"
  )
  bq_mtcars <- dplyr::tbl(con, "mtcars") %>% dplyr::filter(cyl == 4)

  # collect
  x <- dplyr::collect(bq_mtcars)
  expect_equal(dim(x), c(11, 11))

  # compute: temporary
  temp <- dplyr::compute(bq_mtcars)

  # compute: persistent
  name <- random_name()
  temp <- dplyr::compute(bq_mtcars, temporary = FALSE, name = name)
  on.exit(DBI::dbRemoveTable(con, name))

  expect_true(DBI::dbExistsTable(con, name))
})

test_that("collect can identify directly download tables", {
  con <- DBI::dbConnect(
    bigquery(),
    project = bq_test_project(),
    dataset = "basedata"
  )

  bq1 <- dplyr::tbl(con, "mtcars")
  expect_true(op_can_download(bq1$ops))
  expect_equal(op_rows(bq1$ops), Inf)
  expect_equal(as.character(op_table(bq1$ops)), "mtcars")

  bq2 <- head(bq1, 4)
  expect_true(op_can_download(bq2$ops))
  expect_equal(op_rows(bq2$ops), 4)
  expect_equal(as.character(op_table(bq1$ops)), "mtcars")

  bq3 <- head(bq2, 2)
  expect_true(op_can_download(bq3$ops))
  expect_equal(op_rows(bq3$ops), 2)

  bq3 <- dplyr::filter(bq1, cyl == 1)
  expect_false(op_can_download(bq3$ops))

  skip_if_not_installed("dbplyr", "1.2.1.9001")
  x <- dplyr::collect(bq1)
  expect_s3_class(x, "tbl")
})

test_that("casting uses bigquery types", {
  skip_if_not_installed("dbplyr")

  sql <- dbplyr::lazy_frame(x = "1") %>%
    dplyr::mutate(y = as.integer(x), z = as.numeric(x)) %>%
    dbplyr::sql_build(simulate_bigrquery())

  if (utils::packageVersion("dbplyr") > "1.3.0") {
    expect_equal(sql$select[[2]], 'SAFE_CAST(`x` AS INT64)')
    expect_equal(sql$select[[3]], 'SAFE_CAST(`x` AS FLOAT64)')
  } else {
    expect_equal(sql$select[[2]], 'SAFE_CAST(`x` AS INT64) AS `y`')
    expect_equal(sql$select[[3]], 'SAFE_CAST(`x` AS FLOAT64) AS `z`')
  }
})

test_that("%||% translates to IFNULL", {
  skip_if_not_installed("dbplyr")

  sql <- dbplyr::lazy_frame(x = 1L) %>%
    dplyr::mutate(y = x %||% 2L) %>%
    dbplyr::sql_build(simulate_bigrquery())

  if (utils::packageVersion("dbplyr") > "1.3.0") {
    expect_equal(sql$select[[2]], 'IFNULL(`x`, 2)')
  } else {
    expect_equal(sql$select[[2]], 'IFNULL(`x`, 2) AS `y`')
  }
})