def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end

def wait_for(search)
  @browser.find_element(search)
end

# columns go from: A..Z, AA..AZ, BA..BZ,
def char_to_col_index(char)
  return char if char.is_a? Numeric
  return char if char == nil
  pos = 0
  chars = char.split('')
  chars.each do |char|
    # need to be able to calculate columns after AZ
    # currently only accurate up to AZ
    pos = char.upcase.ord - 65
  end
  binding.pry
  pos = pos + 26 * (chars.length - 1)
end
