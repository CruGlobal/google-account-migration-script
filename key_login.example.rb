def login(driver)
  driver.find_element(id: 'username').send_keys 'bill.bright@cru.org'
  driver.find_element(id: 'password').send_keys 'asdf'
  driver.find_element(css: '[type="submit"]').click
end

