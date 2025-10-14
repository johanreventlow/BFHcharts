test_that("sanitize_marquee_text escapes < and >", {
  # Test basic angle bracket escaping
  result <- sanitize_marquee_text("Test <script>")
  expect_true(grepl("&lt;", result))
  expect_false(grepl("<script>", result))

  result <- sanitize_marquee_text("Value > 100")
  expect_true(grepl("&gt;", result))
  expect_false(grepl(">", result, fixed = TRUE))
})

test_that("sanitize_marquee_text escapes HTML entities", {
  # Test ampersand escaping (must be first to avoid double-escaping)
  result <- sanitize_marquee_text("A & B")
  expect_equal(result, "A &amp; B")

  # Test combined escaping
  result <- sanitize_marquee_text("<tag attr='value'>")
  expect_true(grepl("&lt;", result))
  expect_true(grepl("&gt;", result))
  expect_false(grepl("<", result, fixed = TRUE))
  expect_false(grepl(">", result, fixed = TRUE))
})

test_that("sanitize_marquee_text escapes braces", {
  result <- sanitize_marquee_text("Text {markup}")
  expect_true(grepl("&#123;", result))
  expect_true(grepl("&#125;", result))
  expect_false(grepl("{", result, fixed = TRUE))
  expect_false(grepl("}", result, fixed = TRUE))
})

test_that("sanitize_marquee_text handles malicious input", {
  # Potential markup injection attempts
  malicious_inputs <- c(
    "<script>alert('xss')</script>",
    "{.danger **injection**}",
    "< img src=x onerror=alert(1) >",
    "Text & <tag> with {markup}"
  )

  for (input in malicious_inputs) {
    result <- sanitize_marquee_text(input)
    # Should not contain any unescaped special characters
    expect_false(grepl("<", result, fixed = TRUE))
    expect_false(grepl(">", result, fixed = TRUE))
    expect_false(grepl("{", result, fixed = TRUE))
    expect_false(grepl("}", result, fixed = TRUE))
  }
})

test_that("sanitize_marquee_text preserves safe text", {
  safe_text <- "Normal text with numbers 123 and symbols !@#$%^*()"
  result <- sanitize_marquee_text(safe_text)
  # Should preserve most of the text (except angle brackets if present)
  expect_true(grepl("Normal text", result))
  expect_true(grepl("123", result))
})

test_that("sanitize_marquee_text handles NULL and empty", {
  expect_equal(sanitize_marquee_text(NULL), "")
  expect_equal(sanitize_marquee_text(""), "")
  expect_equal(sanitize_marquee_text(character(0)), "")
})

test_that("sanitize_marquee_text truncates long input", {
  long_text <- paste(rep("A", 300), collapse = "")
  result <- sanitize_marquee_text(long_text)
  expect_lte(nchar(result), 200)
  expect_warning(sanitize_marquee_text(long_text), "Text afkortet")
})

test_that("sanitize_marquee_text removes control characters", {
  # Note: R string literals don't preserve literal control characters in source
  # The regex correctly removes control characters when they are actually present
  # This test verifies the function doesn't error on control characters
  text_with_tab <- "Text\twith\ttabs"
  result <- sanitize_marquee_text(text_with_tab)
  # Tabs (\t = \x09) should be removed (it's a control char)
  expect_false(grepl("\t", result, fixed = TRUE))
  expect_true(grepl("Textwithtabs", result))
})

test_that("sanitize_marquee_text preserves newlines", {
  text_with_newline <- "Line 1\nLine 2"
  result <- sanitize_marquee_text(text_with_newline)
  expect_true(grepl("\n", result, fixed = TRUE))
})
