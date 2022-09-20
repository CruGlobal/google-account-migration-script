def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end

def wait_for(search)
  @browser.find_element(search)
end

# Supports up to 2-letter columns following pattern: A..Z, AA..AZ, BA..BZ, ZA..ZZ
def char_to_col_index(char)
  return char if char.is_a? Numeric
  return char if char == nil

  chars = char.split('')

  if chars.length == 1
    total = (chars[0].upcase.ord - 65)
  elsif chars.length == 2
    total = ((chars[0].upcase.ord - 64) * 26) + (chars[1].upcase.ord - 65)
  end
  total
end
