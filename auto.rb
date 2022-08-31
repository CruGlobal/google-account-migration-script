require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'

  gem 'activesupport'
  gem 'selenium-webdriver'
  gem 'google_drive'
  gem 'pry-byebug'
  gem 'yaml'
  gem 'oktakit'
end

require 'active_support/all'
require 'selenium-webdriver'
require 'google_drive'
require 'pry-byebug'
require 'yaml'
require 'oktakit'

LOGIN_HELPER_FILE = './key_login.rb'
def login(_browser); end
if File.file?(File.expand_path LOGIN_HELPER_FILE)
  require LOGIN_HELPER_FILE
end

require_relative 'helpers.rb'

CONFIG = YAML.load_file("config.yml")
raise 'No config given' if CONFIG == false || CONFIG.keys.none?

CAS_MANAGE_SEARCH_PAGE = 'https://thekey.me/cas-management/users/admin'
SPREADSHEET_KEY = CONFIG['spreadsheet']['key']
SHEET_INDEX = CONFIG['spreadsheet']['index']
G_GROUP_NAME = CONFIG['g_group_name']

# use the actual row numbers (the first row is 1, not 0)
START_ROW_NUMBER = ENV['START_ROW_NUMBER']&.to_i || CONFIG['start_row_number']
END_ROW_NUMBER = ENV['END_ROW_NUMBER']&.to_i || CONFIG['end_row_number']
# example to run this on specific rows:
# START_ROW_NUMBER=260 END_ROW_NUMBER=387 PROFILE_NUMBER=2 ruby auto.rb

EXISTING_EMAIL_COLUMN_INDEX= char_to_col_index CONFIG['existing_email_column_index']
DESIRED_EMAIL_COLUMN_INDEX= char_to_col_index CONFIG['desired_email_column_index']
FIRST_NAME_COLUMN_INDEX= char_to_col_index CONFIG['first_name_column_index']
PREFERRED_NAME_COLUMN_INDEX= char_to_col_index CONFIG['preferred_name_column_index']
LAST_NAME_COLUMN_INDEX= char_to_col_index CONFIG['last_name_column_index']
PASSWORD_COLUMN_INDEX= char_to_col_index CONFIG['password_column_index']
NOTE_COLUMN_INDEX= char_to_col_index CONFIG['note_column_index']
ALIAS_COLUMN_INDEX= char_to_col_index CONFIG['alias_column_index']

$change_email_allowed = true
$dry_run = false
$only_one = false

def setup_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument(user_data_dir)
  @browser = Selenium::WebDriver.for :chrome, options: options
  @browser.navigate.to CAS_MANAGE_SEARCH_PAGE

  login(@browser)

  wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
  wait.until { @browser.find_element(css: 'input#email') }
end

def user_data_dir
  return "user-data-dir=./profile" unless ENV['PROFILE_NUMBER']
  "user-data-dir=./profile-#{ENV['PROFILE_NUMBER']}"
end

def connect_to_drive_file
  session = GoogleDrive::Session.from_config("config.json")
  ws = session.spreadsheet_by_key(SPREADSHEET_KEY).worksheets[SHEET_INDEX]
  @headers = ws.rows.first.map(&:strip)
  @file = ws
end

def loop_over_rows
  rows = @file.rows[(START_ROW_NUMBER - 1)..(END_ROW_NUMBER - 1)]
  rows.each_with_index do |r, index|
    run_cleanup(r, index)

    break if $only_one
  end
end

# order from Scott on 2020-02-06
# 1. Search on "K" change email to "C" (save)
# 2 Search on "C" then change names (save)
# 3 Search on "C" then Reset MFA
# 4 change password (save)
# 5 Search on "C" then change then change Google Organization, (wait)
# 6 Search on "C" then change aliases
def run_cleanup(r, index)
  return unless filter_row?(r)

  @okta_user = nil
  return if r[NOTE_COLUMN_INDEX] == 'success'
  puts ''
  print "#{index + START_ROW_NUMBER}: "
  update_email_and_name(r)
  new_email = nil
  new_email = r[DESIRED_EMAIL_COLUMN_INDEX] if $change_email_allowed

  set_password(r)

  if PASSWORD_COLUMN_INDEX.present? && r[PASSWORD_COLUMN_INDEX].present?
    reset_the_key_mfa(r, new_email)
    reset_okta_mfa(r)
  end

  change_group(r)

  if ALIAS_COLUMN_INDEX
    add_aliases(r)
  end

  success_message = $dry_run ? 'dry run success' : 'success'
  save_note(index + START_ROW_NUMBER, success_message)
rescue => error
  puts error.backtrace
  save_note(index + START_ROW_NUMBER, error.message)
end

def filter_row?(r)
  r[EXISTING_EMAIL_COLUMN_INDEX].present?
end

# done
def go_to_profile(r, email = nil, reload = false)
  email ||= r[EXISTING_EMAIL_COLUMN_INDEX]

  raise "no email provided" if email == ''

  go_to_search_page(reload)

  element = @browser.find_element(css: 'input#email')
  element.clear
  element.send_keys email
  find_button(@browser, 'Search').click

  check_for_multiple_results

  find_button(@browser, 'Edit').click
  true
end

def go_to_search_page(reload)
  h1 = @browser.find_element(css: 'h1')
  return if !reload && h1.text == 'User Search' && h1.displayed?

  @browser.navigate.to CAS_MANAGE_SEARCH_PAGE
  @browser.find_element(css: '.card.mb-3 input#email')
end

# done
def check_for_multiple_results
  count = @browser.find_elements(class: "main-row").count
  if count > 1
    raise "more than 1 result"
  end

  if count == 0
    raise "person not found"
  end
end

def update_email_and_name(row)
  new_profile_attributes = {
    firstName: row[FIRST_NAME_COLUMN_INDEX],
    lastName: row[LAST_NAME_COLUMN_INDEX]
  }
  new_profile_attributes[:nickName] = row[PREFERRED_NAME_COLUMN_INDEX].to_s if PREFERRED_NAME_COLUMN_INDEX

  existing_email = row[EXISTING_EMAIL_COLUMN_INDEX]
  found_email = nil
  if $change_email_allowed
    new_email = okta_email(row)
    profile = begin
        existing = okta_profile(existing_email)
        found_email = existing_email
        existing
      rescue Oktakit::NotFound
        nil
      end
    profile ||= okta_profile(new_email)
    found_email ||= new_email

    if profile[:login] != new_email || profile[:email] != new_email
      new_profile_attributes[:login] = new_email
      new_profile_attributes[:email] = new_email
    end
  end

  puts "I would have updated #{existing_email} with: #{new_profile_attributes}" if $dry_run
  return if $dry_run
  okta_client.update_profile(found_email, profile: new_profile_attributes)
end

def set_password(row)
  print ", password"
  return if $dry_run
  return unless PASSWORD_COLUMN_INDEX.present? && row[PASSWORD_COLUMN_INDEX].present?

  okta_client.update_profile(okta_email(row), credentials: { password: { value: row[PASSWORD_COLUMN_INDEX] } })
  okta_user_id = okta_user(okta_email(row), true)[:id]
  okta_client.expire_password(okta_user_id)
  sleep 2
end

# done
def reset_the_key_mfa(row, new_email)
  go_to_profile(row, new_email)
  @browser.find_element(css: '[data-target="#mfaCollapsible"]').click

  mfa_enabled = @browser.find_elements(css: '[name="_eventId_resetMfaSecret"]').count > 0
  return unless mfa_enabled

  return if $dry_run
  sleep 0.5
  @browser.find_element(css: '[name="_eventId_resetMfaSecret"]').click
  # wait a half second for page to save
  sleep 0.5
end

def reset_okta_mfa(row)
  return if $dry_run

  okta_user_id = okta_user(okta_email(row), true)[:id]
  okta_client.reset_factors(okta_user_id)
end

def change_group(row)
  return if group_names(row)&.empty?

  group_names(row).each do |group_name|
    okta_group_id = find_group_id(group_name)
    okta_user_id = okta_user(okta_email(row), true)[:id]

    if $dry_run
      puts "I would have added #{okta_user_id} to group #{okta_group_id}"
      next
    end
    okta_client.add_user_to_group(okta_group_id, okta_user_id)
  end
end

def find_group_id(group_name)
  resp, _code = okta_client.list_groups(query: { q: group_name, limit: 1 })
  raise "group name doesn't match exactly" unless resp&.first&.to_h&.dig(:profile, :name) == group_name
  resp.first[:id]
end

def group_names(row)
  return if G_GROUP_NAME.is_a?(String) && !G_GROUP_NAME.strip.present?
  # return Array.wrap(G_GROUP_NAME) if G_GROUP_NAME.is_a?(String) || G_GROUP_NAME.is_a?(Array)

  group_names = row[char_to_col_index(G_GROUP_NAME)]
  return if group_names.nil?
  group_names.split(/[ ,]/).map(&:strip).reject { |s| s == '' }
end

def add_aliases(row)
  aliases = row[ALIAS_COLUMN_INDEX].to_s.downcase.strip
  return unless aliases.length > 0

  okta_aliases = okta_profile(okta_email(row))[:emailAliases] || []
  existing_fixed_aliases = okta_aliases.map { |s| s.split(',') }.flatten.uniq
  new_aliases = aliases.split(/[ ,]/).map(&:strip)
  combined_aliases = (existing_fixed_aliases + new_aliases).uniq

  different_aliases = combined_aliases - okta_aliases

  if $dry_run
    puts "I would have added #{different_aliases} as alias"
    puts "Debug: o_a: #{okta_aliases}\ne_f_a: #{existing_fixed_aliases}\nn_a: #{new_aliases}\nc_a: #{combined_aliases}"
    return
  end
  okta_client.update_profile(okta_email(row), profile: { emailAliases: combined_aliases }) if different_aliases.any?
end

def save_note(row_number, text)
  return if @file[row_number, NOTE_COLUMN_INDEX + 1] == text
  @file[row_number, NOTE_COLUMN_INDEX + 1] = text
  @file.save
  sleep 0.5
end

def run
  connect_to_drive_file
  setup_browser
  loop_over_rows
end

def okta_email(row)
  $change_email_allowed ? row[DESIRED_EMAIL_COLUMN_INDEX] : row[EXISTING_EMAIL_COLUMN_INDEX]
end

def okta_client
  @okta_client ||= Oktakit.new(token: CONFIG['okta_token'], api_endpoint: CONFIG['okta_api_endpoint'])
end

def okta_user(email, use_cache = false)
  return @okta_user if @okta_user && use_cache
  # https://developer.okta.com/docs/reference/api/users/#get-user-with-login
  response, _http_status = okta_client.get_user(email)
  @okta_user = response
end

def okta_profile(email, use_cache = false)
  okta_user(email, use_cache)[:profile]
end

begin
  run
  p 'done! 🎉'
  sleep 1
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
