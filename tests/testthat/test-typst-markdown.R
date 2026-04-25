test_that("markdown_to_typst: null og tom input returnerer tom streng", {
  expect_equal(markdown_to_typst(NULL), "")
  expect_equal(markdown_to_typst(""), "")
  expect_equal(markdown_to_typst(character(0)), "")
})

test_that("markdown_to_typst: plain text passerer uændret igennem", {
  expect_equal(markdown_to_typst("plain text"), "plain text")
  expect_equal(markdown_to_typst("Hello world"), "Hello world")
})

test_that("markdown_to_typst: bold og italic konverteres korrekt", {
  expect_equal(markdown_to_typst("**bold**"), "#strong[bold]")
  expect_equal(markdown_to_typst("*italic*"), "#emph[italic]")
  expect_equal(markdown_to_typst("This is **important** text"), "This is #strong[important] text")
  expect_equal(markdown_to_typst("This is *emphasized* text"), "This is #emph[emphasized] text")
})

test_that("markdown_to_typst: mixed bold og italic i samme streng", {
  result <- markdown_to_typst("**bold** and *italic*")
  expect_equal(result, "#strong[bold] and #emph[italic]")
})

test_that("markdown_to_typst: inline code producerer Typst raw", {
  result <- markdown_to_typst("Use `code` here")
  expect_equal(result, 'Use #raw("code") here')
})

test_that("markdown_to_typst: newline konverteres til Typst linjeskift", {
  result <- markdown_to_typst("Line 1\nLine 2")
  expect_equal(result, "Line 1\\\nLine 2")
})

test_that("markdown_to_typst: to paragraffer adskilles med linjeskift", {
  result <- markdown_to_typst("Para 1\n\nPara 2")
  # Dobbelt-newline (paragraph-skift) → ét linjeskift i Typst content block
  expect_equal(result, "Para 1\\\nPara 2")
})

# ===========================================================================
# 3.2 INJECTION-TESTS
# ===========================================================================

test_that("markdown_to_typst: Typst-direktiver escapes (#import, #let)", {
  expect_equal(markdown_to_typst("#import malicious"), "\\#import malicious")
  expect_equal(markdown_to_typst("#let x = 1"), "\\#let x = 1")
  expect_equal(markdown_to_typst("text #strong[injected]"), "text \\#strong\\[injected\\]")
})

test_that("markdown_to_typst: math-mode injection escapes ($)", {
  expect_equal(markdown_to_typst("$math$"), "\\$math\\$")
  expect_equal(markdown_to_typst("cost is $100"), "cost is \\$100")
})

test_that("markdown_to_typst: bracket injection escapes ([ ])", {
  expect_equal(markdown_to_typst("[bracket]"), "\\[bracket\\]")
  # CommonMark parserer [link text](url) som link-node — vi renderer kun teksten
  expect_equal(markdown_to_typst("[link text](url)"), "link text")
})

test_that("markdown_to_typst: reference/citation injection escapes (@)", {
  expect_equal(markdown_to_typst("@package injection"), "\\@package injection")
  expect_equal(markdown_to_typst("see @fig:chart"), "see \\@fig:chart")
})

test_that("markdown_to_typst: angle bracket injection escapes (< >)", {
  # CommonMark parserer <script> og <label> som html_block (trailing newline fjernes)
  expect_equal(markdown_to_typst("<script>"), "\\<script\\>")
  expect_equal(markdown_to_typst("<label>"), "\\<label\\>")
  # Inline angle brackets i almindelig tekst escapes
  expect_equal(markdown_to_typst("value < 10"), "value \\< 10")
  expect_equal(markdown_to_typst("a > b"), "a \\> b")
})

test_that("markdown_to_typst: raw mode injection escapes (backtick)", {
  # Backtick i plain text (ikke som markdown code) skal escapes
  result <- markdown_to_typst("price is 5`000")
  expect_true(grepl("\\\\`", result))
})

test_that("markdown_to_typst: bold markup injection escapes (* i plain text)", {
  # Uparret asterisk i plain text skal escapes for at undgå ukorrekt Typst markup
  result <- markdown_to_typst("3*4 = 12")
  expect_equal(result, "3\\*4 = 12")
})

test_that("markdown_to_typst: scripting construct kan ikke injecte Typst funktioner", {
  # #show regel via markdown heading bruges som injection vector
  result <- markdown_to_typst("#show: evil_template.with()")
  expect_true(grepl("^\\\\#show", result))
  expect_false(grepl("^#show:", result))
})

# ===========================================================================
# 3.3 EDGE CASES
# ===========================================================================

test_that("markdown_to_typst: nested emphasis håndteres korrekt", {
  result <- markdown_to_typst("**bold *italic* bold**")
  expect_equal(result, "#strong[bold #emph[italic] bold]")
})

test_that("markdown_to_typst: underscore i plain text escapes", {
  expect_equal(markdown_to_typst("snake_case_var"), "snake\\_case\\_var")
})

test_that("markdown_to_typst: backslash i plain text escapes", {
  result <- markdown_to_typst("C:\\path\\to\\file")
  expect_equal(result, "C:\\\\path\\\\to\\\\file")
})

test_that("markdown_to_typst: unicode passerer igennem uden escaping", {
  expect_equal(markdown_to_typst("Ærø café naïve"), "Ærø café naïve")
  expect_equal(markdown_to_typst("Sundhed & Velvære"), "Sundhed & Velvære")
})

test_that("markdown_to_typst: subscript og superscript chars escapes (~ ^)", {
  result_tilde <- markdown_to_typst("H~2~O")
  expect_true(grepl("\\\\~", result_tilde))

  result_caret <- markdown_to_typst("x^2^")
  expect_true(grepl("\\\\\\^", result_caret))
})

test_that("markdown_to_typst: bullet list producerer Typst list items", {
  result <- markdown_to_typst("- item1\n- item2")
  expect_true(grepl("- item1", result))
  expect_true(grepl("- item2", result))
})

# ===========================================================================
# 3.4 BACKWARD COMPAT: standard dokumenteret markdown giver konsistent output
# ===========================================================================

test_that("markdown_to_typst: backward compat — titel med bold konklusion", {
  input <- "Write a title or\n**conclude what the chart shows**"
  result <- markdown_to_typst(input)
  # Bold del skal konverteres
  expect_true(grepl("#strong\\[conclude what the chart shows\\]", result))
  # Linjeskift fra \n
  expect_true(grepl("\\\\\n", result))
})

test_that("markdown_to_typst: backward compat — analyse med italic og newlines", {
  input <- "Stabil proces.\n*Ingen særlig årsag* detekteret."
  result <- markdown_to_typst(input)
  expect_true(grepl("#emph\\[Ingen særlig årsag\\]", result))
  expect_true(grepl("Stabil proces", result))
})

# ===========================================================================
# escape_typst_text direkte tests
# ===========================================================================

test_that("escape_typst_text: NULL og tom streng håndteres", {
  expect_equal(escape_typst_text(NULL), "")
  expect_equal(escape_typst_text(""), "")
})

test_that("escape_typst_text: alle Typst special chars escapes", {
  expect_equal(escape_typst_text("#"), "\\#")
  expect_equal(escape_typst_text("$"), "\\$")
  expect_equal(escape_typst_text("@"), "\\@")
  expect_equal(escape_typst_text("_"), "\\_")
  expect_equal(escape_typst_text("*"), "\\*")
  expect_equal(escape_typst_text("["), "\\[")
  expect_equal(escape_typst_text("]"), "\\]")
  expect_equal(escape_typst_text("<"), "\\<")
  expect_equal(escape_typst_text(">"), "\\>")
  expect_equal(escape_typst_text("`"), "\\`")
  expect_equal(escape_typst_text("~"), "\\~")
  expect_equal(escape_typst_text("^"), "\\^")
})

test_that("escape_typst_text: backslash escapes korrekt (ingen double-escaping)", {
  # Enkelt backslash → dobbelt backslash i output
  expect_equal(escape_typst_text("\\"), "\\\\")
  # Backslash + hash: backslash escapes FØRST
  expect_equal(escape_typst_text("\\#"), "\\\\\\#")
})
